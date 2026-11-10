local _, ns = ...

-- The macro editor: a real multi-line EditBox draws the caret and takes typing, while every visible string is an
-- overlay FontString built from ns.Highlight. The EditBox's own text is transparent, so colour codes never count
-- against its 255 letters. The caret, current-line highlight, gutter numbers, squiggles and popup all use the
-- EditBox's own cursor rect for the caret and a hidden FontString wrapped at the EditBox's width and word wrap for
-- every other row, never an average glyph advance or a fixed column count.

local L = ns.L

local FONT_NAME = "MacroAssistMono"
local FONT_SIZE = 14
-- Extra space below each line (SetSpacing), so 14-unit text reads on 19-unit lines.
local LINE_SPACING = 5
local GUTTER_WIDTH = 30
local TEXT_INSET_LEFT = 2
local TEXT_INSET_RIGHT = 2
local TEXT_INSET_TOP = 2
local SQUIGGLE_HEIGHT = 4
local POPUP_ROWS = 8
local POPUP_ROW_HEIGHT = 22
-- common-dropdown-bg keeps its corners at their native size: UiTextureAtlasElementSliceData gives it a
-- 16 / 13 / 16 / 19 unit border (left, top, right, bottom) in UI units. Blizzard's own menus put their content
-- inside that border too (MenuStyle1Mixin:GetInset is 8/8/8/15 around a background that extends 10 more out),
-- so rows are inset by the border itself and label, detail and highlight all stay inside it.
local POPUP_INSET_LEFT = 16
local POPUP_INSET_TOP = 13
local POPUP_INSET_RIGHT = 16
local POPUP_INSET_BOTTOM = 19

local COLOUR_CLOSE = "|r"
local COLOUR_GREEN = "|cff33ff99"
local COLOUR_RED = "|cffff4040"
local COLOUR_YELLOW = "|cffffd100"
local COLOUR_MUTED = "|cff9d9d9d"

local CODE_KINDS = {
	secure = true,
	command = true,
	chat = true,
	emote = true,
	directive = true,
	condition = true,
	unit = true,
	value = true,
}

local BADGES = {
	secure = "/",
	command = "/",
	chat = "/",
	emote = "/",
	directive = "#",
	condition = "[",
	unit = "@",
	spell = "S",
	value = "=",
}

local function EnsureFont()
	if _G[FONT_NAME] then
		return
	end
	local font = CreateFont("MacroAssistMono")
	font:SetFont("Interface/AddOns/MacroAssistForever/media/fonts/JetBrainsMono-Regular.ttf", FONT_SIZE, "")
	font:SetJustifyH("LEFT")
	font:SetSpacing(LINE_SPACING)
end

---@param text string
---@param from integer
---@param to integer
---@return string
local function Replace(text, from, to, insert)
	return text:sub(1, from - 1) .. insert .. text:sub(to + 1)
end

-- One visual row: a logical line, or one of its client word-wrapped pieces. `from` and `to` are absolute byte
-- offsets in the whole macro; `to` is exclusive, so an empty row has from == to. `y` is the row's top inside the
-- text area, already multiplied by the measured line height.
---@class MacroAssistEditorRow
---@field line integer
---@field row integer
---@field from integer
---@field to integer
---@field text string
---@field y number

---@class MacroAssistTextMeasure
---@field width fun(text: string): number

-- A click that is waiting for the EditBox to report where it put the cursor. `row` is the visual row under the
-- pointer when the button went down, `upRow` the row on release, and `x` the pointer's offset from the edit's left
-- edge. `pending` is set when the live cursor position could not resolve the click, so the next cursor update gets
-- exactly one chance to place it, on the row the client's y reports.
---@class MacroAssistEditorClick
---@field row integer?
---@field upRow integer?
---@field x number?
---@field pending boolean?

---@class MacroAssistEditor
---@field parent Frame
---@field gutter Frame
---@field textArea Frame
---@field overlay Frame
---@field edit EditBox
---@field measure FontString
---@field probe FontString
---@field textMeasure MacroAssistTextMeasure
---@field highlight Texture
---@field caret MacroAssistCaret
---@field caretBlink AnimationGroup
---@field status FontString
---@field popup MacroAssistCompletionPopup
---@field lineFonts FontString[]
---@field numberFonts FontString[]
---@field squiggles MacroAssistSquiggle[]
---@field completion MacroAssistCompletionState
---@field rows MacroAssistEditorRow[]
---@field diagnostics MacroAssistDiagnostic[]
---@field parsed MacroAssistParse?
---@field cursorX number?
---@field cursorY number?
---@field cursorWidth number?
---@field cursorHeight number?
---@field cursorRow integer? the visual row (1-based) from the EditBox's cursor y
---@field click MacroAssistEditorClick?
---@field resolvingClick boolean?
---@field lineHeight number
---@field wrapWidth number
---@field setting boolean
---@field inCombat boolean
---@field onEdited? fun()
---@field onEscape? fun()
local Editor = {}

-- The byte offset of every UTF-8 character start, plus a final sentinel at #text + 1, so a cursor position can
-- only land between characters. The client's Lua strings are byte strings; players still type multibyte names.
---@param text string
---@return integer[]
local function Boundaries(text)
	local out = { 1 }
	local index = 1
	local length = #text
	while index <= length do
		index = index + 1
		while index <= length do
			local byte = text:byte(index)
			if byte < 128 or byte >= 192 then
				break
			end
			index = index + 1
		end
		out[#out + 1] = index
	end
	return out
end

local IsSpace = ns.Lexer.IsSpace

-- The next run of non-space characters from `index`, with its byte range, or nil when only spaces remain.
---@param line string
---@param index integer
---@return integer? wordStart
---@return integer? wordEnd
local function NextWord(line, index)
	local length = #line
	while index <= length and IsSpace(line:byte(index)) do
		index = index + 1
	end
	if index > length then
		return nil
	end
	local start = index
	while index <= length and not IsSpace(line:byte(index)) do
		index = index + 1
	end
	return start, index - 1
end

-- The last character of the longest run from `from` through `to` whose single-line width fits `width`. This is a
-- binary search because a long word would otherwise cost one client measurement per character on every keystroke;
-- one character is always returned so a too-narrow edit still makes progress.
---@param line string
---@param from integer
---@param to integer
---@param width number
---@param measure MacroAssistTextMeasure
---@return integer
local function FitEnd(line, from, to, width, measure)
	local bounds = Boundaries(line:sub(from, to))
	local low, high = 1, #bounds
	while low < high do
		local middle = math.ceil((low + high) / 2)
		local last = from + bounds[middle] - 2
		if measure.width(line:sub(from, last)) <= width then
			low = middle
		else
			high = middle - 1
		end
	end
	local last = from + bounds[low] - 2
	if last < from then
		last = from
	end
	return last
end

-- Every visual row of the macro, in drawing order. A row takes as many whole words as fit at the measured width;
-- the spaces after its last word stay on that row and the next row starts with a word, which is the client's
-- word-wrap shape. A word too wide for a whole row is broken at the longest measured prefix, as the client does.
-- The alternative, GetNumLines on a prefix, sees a truncated word as a complete one and can split a word that the
-- full line would have moved whole, so the width search is used. Rows are computed on text or width changes only.
---@param text string
---@param width number
---@param lineHeight number
---@param measure MacroAssistTextMeasure
---@return MacroAssistEditorRow[]
function Editor.LayoutRows(text, width, lineHeight, measure)
	local parsed = ns.Parser.Parse(text)
	local rows = {}
	local y = 0
	for lineIndex, line in ipairs(parsed.lines) do
		local length = #line.text
		if length == 0 then
			rows[#rows + 1] = {
				line = lineIndex,
				row = 0,
				from = line.from,
				to = line.from,
				text = "",
				y = y,
			}
			y = y + lineHeight
		else
			local start = 1
			local rowIndex = 0
			while start <= length do
				local finish
				local nextStart
				local placedEnd
				local index = start
				while true do
					local wordStart, wordEnd = NextWord(line.text, index)
					if not wordStart or not wordEnd then
						nextStart = length + 1
						break
					end
					local candidate = line.text:sub(start, wordEnd)
					if measure.width(candidate) <= width then
						placedEnd = wordEnd
					elseif placedEnd then
						finish = wordStart - 1
						nextStart = wordStart
						break
					else
						finish = FitEnd(line.text, start, wordEnd, width, measure)
						nextStart = finish + 1
						break
					end
					index = wordEnd + 1
				end
				finish = finish or length
				rows[#rows + 1] = {
					line = lineIndex,
					row = rowIndex,
					from = line.from + start - 1,
					to = line.from + finish,
					text = line.text:sub(start, finish),
					y = y,
				}
				rowIndex = rowIndex + 1
				y = y + lineHeight
				start = nextStart or (length + 1)
			end
		end
	end
	return rows
end

-- The visual row (1-based) a 0-based cursor position sits on. A position at a wrap belongs to the following row;
-- at the end of a logical line it belongs to that line's last row, because that is where its newline is typed.
---@param rows MacroAssistEditorRow[]
---@param cursor integer
---@return integer? rowIndex
function Editor.RowAtCursor(rows, cursor)
	if not rows or #rows == 0 then
		return nil
	end
	local position = math.max(0, cursor) + 1
	for index, row in ipairs(rows) do
		local last = not rows[index + 1] or rows[index + 1].line ~= row.line
		if position >= row.from and (position < row.to or (position == row.to and last)) then
			return index
		end
	end
	return #rows
end

-- A 0-based cursor position's x offset from the left edge of its visual row, measured on the row's own text. A
-- wrapped row always starts at the edit's left edge, so this is the width of the row prefix before the cursor.
---@param row MacroAssistEditorRow
---@param cursor integer
---@param measure MacroAssistTextMeasure
---@return number
function Editor.RowOffset(row, cursor, measure)
	local offset = cursor - (row.from - 1)
	if offset < 0 then
		offset = 0
	elseif offset > #row.text then
		offset = #row.text
	end
	return measure.width(row.text:sub(1, offset))
end

-- The character on this row nearest a pointer x, as a 0-based cursor position. Past the row's last character this
-- is the row's end, which is before the newline on a logical line's last row and before the next row's text at a
-- wrap. Never past the newline: that is the bug a click right of a line's end has with the EditBox's own handling.
---@param row MacroAssistEditorRow
---@param x number pointer x offset from the edit's left edge
---@param measure MacroAssistTextMeasure
---@return integer cursor
function Editor.ClickTarget(row, x, measure)
	local bounds = Boundaries(row.text)
	local bestOffset = 0
	local bestDistance = math.abs(x)
	for index = 1, #bounds do
		local offset = bounds[index] - 1
		local distance = math.abs(measure.width(row.text:sub(1, offset)) - x)
		if distance < bestDistance then
			bestDistance = distance
			bestOffset = offset
		end
	end
	return row.from - 1 + bestOffset
end

-- The click rule, kept free of client calls so the spec can exercise it. A release on the row that was pressed
-- only moves the cursor when the EditBox put it on a different row; a click on the row the EditBox already reports
-- changes nothing. `downRow`, `upRow` and `cursorRow` are 1-based visual rows, `x` is from the edit's left edge.
---@param rows MacroAssistEditorRow[]
---@param downRow integer?
---@param upRow integer?
---@param cursorRow integer?
---@param x number?
---@param measure MacroAssistTextMeasure
---@return integer? cursor
function Editor.ClickCursor(rows, downRow, upRow, cursorRow, x, measure)
	if not rows or not downRow or downRow ~= upRow or not x then
		return nil
	end
	if cursorRow == downRow then
		return nil
	end
	local row = rows[downRow]
	if not row then
		return nil
	end
	return Editor.ClickTarget(row, x, measure)
end

---@class MacroAssistCompletionState
---@field items MacroAssistCompletionItem[]
---@field from integer
---@field to integer
---@field selected integer
---@field offset integer

---@class MacroAssistCompletionRow : Button
---@field badge FontString
---@field label FontString
---@field detail FontString
---@field highlight Texture

---@class MacroAssistCompletionPopup : Frame
---@field bg Texture
---@field rows MacroAssistCompletionRow[]

---@class MacroAssistSquiggle : Frame
---@field texture Texture

---@class MacroAssistCaret : Frame
---@field texture Texture

---@param parent Frame
---@return MacroAssistEditor
function Editor.Create(parent)
	EnsureFont()
	local self = setmetatable({}, { __index = Editor }) --[[@as MacroAssistEditor]]
	self.parent = parent
	self.setting = false
	self.inCombat = false
	self.lineFonts = {}
	self.numberFonts = {}
	self.squiggles = {}
	self.rows = {}
	self.completion = { items = {}, from = 1, to = 0, selected = 1, offset = 0 }

	self.gutter = CreateFrame("Frame", nil, parent)
	self.gutter:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -6)
	self.gutter:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 4, 26)
	self.gutter:SetWidth(GUTTER_WIDTH)

	self.textArea = CreateFrame("Frame", nil, parent)
	self.textArea:SetPoint("TOPLEFT", self.gutter, "TOPRIGHT", 2, 0)
	self.textArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -6, 26)

	self.highlight = self.textArea:CreateTexture(nil, "BACKGROUND")
	self.highlight:SetColorTexture(1, 0.82, 0.2, 0.10)
	self.highlight:Hide()

	-- Draw order: highlight, squiggles, coloured overlay, then the EditBox frame. The EditBox's text is transparent,
	-- so raising its frame level makes its caret draw above the overlay without covering the coloured text.
	self.overlay = CreateFrame("Frame", nil, self.textArea)
	self.overlay:SetAllPoints(self.textArea)
	self.overlay:SetFrameLevel(self.textArea:GetFrameLevel() + 2)

	self.edit = CreateFrame("EditBox", nil, self.textArea)
	self.edit:SetPoint("TOPLEFT", self.textArea, "TOPLEFT", TEXT_INSET_LEFT, -TEXT_INSET_TOP)
	self.edit:SetPoint("BOTTOMRIGHT", self.textArea, "BOTTOMRIGHT", -TEXT_INSET_RIGHT, TEXT_INSET_TOP)
	self.edit:SetMultiLine(true)
	self.edit:SetAutoFocus(false)
	self.edit:SetMaxLetters(ns.MacroLimit)
	self.edit:SetCountInvisibleLetters(true)
	self.edit:SetTextInsets(0, 0, 0, 0)
	self.edit:SetFontObject(FONT_NAME)
	self.edit:SetSpacing(LINE_SPACING)
	self.edit:SetTextColor(1, 1, 1, 0)
	self.edit:SetJustifyH("LEFT")
	self.edit:SetFrameLevel(self.textArea:GetFrameLevel() + 3)

	-- The client has no caret colour or caret texture API: SimpleEditBoxAPI only exposes Get/SetBlinkSpeed, and an
	-- EditBox draws its caret in its text colour, which is transparent here so the coloured overlay shows. Draw
	-- our own white caret above the overlay, one line tall, at the cursor rect OnCursorChanged reports.
	-- A repeating alpha AnimationGroup blinks it; there is no OnUpdate or timer.
	self.caret = CreateFrame("Frame", nil, self.textArea) --[[@as MacroAssistCaret]]
	self.caret:SetFrameLevel(self.textArea:GetFrameLevel() + 5)
	self.caret:SetSize(1, self.lineHeight or (FONT_SIZE + LINE_SPACING))
	self.caret.texture = self.caret:CreateTexture(nil, "ARTWORK")
	self.caret.texture:SetAllPoints(self.caret)
	self.caret.texture:SetColorTexture(1, 1, 1, 1)
	self.caret:Hide()
	self.caretBlink = self.caret:CreateAnimationGroup()
	self.caretBlink:SetLooping("REPEAT")
	local on = self.caretBlink:CreateAnimation("Alpha")
	on:SetFromAlpha(1)
	on:SetToAlpha(1)
	on:SetDuration(0.5)
	on:SetOrder(1)
	local off = self.caretBlink:CreateAnimation("Alpha")
	off:SetFromAlpha(0)
	off:SetToAlpha(0)
	off:SetDuration(0.5)
	off:SetOrder(2)

	-- The hidden measuring copy of the EditBox's text: same font object, spacing, width and word wrap. Width
	-- measurements switch its wrap off for one call so a long run reports its whole width. `probe` supplies the
	-- font's line height and spacing, which set the pitch.
	self.measure = self.textArea:CreateFontString(nil, "ARTWORK", "MacroAssistMono")
	self.measure:SetJustifyH("LEFT")
	self.measure:SetSpacing(LINE_SPACING)
	self.measure:SetWordWrap(true)
	self.measure:SetAlpha(0)
	self.probe = self.textArea:CreateFontString(nil, "ARTWORK", "MacroAssistMono")
	self.probe:SetSpacing(LINE_SPACING)
	self.probe:SetAlpha(0)
	self.textMeasure = {
		width = function(value)
			-- A row prefix is one line by construction; measuring it with wrap off reports the whole run instead
			-- of clamping it to the editor's width, which is what the word-run search needs near the edge.
			self.measure:SetWordWrap(false)
			self.measure:SetText(value)
			local width = self.measure:GetStringWidth()
			self.measure:SetText("")
			self.measure:SetWordWrap(true)
			return type(width) == "number" and width or 0
		end,
	}
	self.lineHeight = FONT_SIZE + LINE_SPACING
	self:UpdateMetrics()

	self.status = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	self.status:SetPoint("LEFT", parent, "LEFT", 10, 10)
	self.status:SetPoint("RIGHT", parent, "RIGHT", -10, 10)
	self.status:SetJustifyH("LEFT")
	self.status:SetWordWrap(false)

	self.popup = CreateFrame("Frame", nil, self.textArea) --[[@as MacroAssistCompletionPopup]]
	self.popup:SetFrameStrata("DIALOG")
	self.popup:SetFrameLevel(self.textArea:GetFrameLevel() + 20)
	self.popup:SetClampedToScreen(true)
	self.popup:EnableMouse(true)
	self.popup:Hide()
	self.popup.bg = self.popup:CreateTexture(nil, "BACKGROUND")
	self.popup.bg:SetAllPoints(self.popup)
	self.popup.bg:SetAtlas("common-dropdown-bg")
	self.popup.bg:SetAlpha(0.94)
	self.popup.rows = {}
	for index = 1, POPUP_ROWS do
		local row = CreateFrame("Button", nil, self.popup) --[[@as MacroAssistCompletionRow]]
		row:SetHeight(POPUP_ROW_HEIGHT)
		row:SetPoint("LEFT", self.popup, "LEFT", POPUP_INSET_LEFT, 0)
		row:SetPoint("RIGHT", self.popup, "RIGHT", -POPUP_INSET_RIGHT, 0)
		if index == 1 then
			row:SetPoint("TOP", self.popup, "TOP", 0, -POPUP_INSET_TOP)
		else
			row:SetPoint("TOP", self.popup.rows[index - 1], "BOTTOM", 0, 0)
		end
		row.highlight = row:CreateTexture(nil, "BACKGROUND")
		row.highlight:SetAllPoints(row)
		row.highlight:SetColorTexture(1, 0.82, 0.2, 0.18)
		row.highlight:Hide()
		row.badge = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.badge:SetPoint("LEFT", row, "LEFT", 2, 0)
		row.badge:SetWidth(14)
		row.badge:SetJustifyH("CENTER")
		row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		row.label:SetPoint("LEFT", row.badge, "RIGHT", 4, 0)
		row.label:SetPoint("RIGHT", row, "RIGHT", -150, 0)
		row.label:SetJustifyH("LEFT")
		row.label:SetWordWrap(false)
		row.detail = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.detail:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		row.detail:SetWidth(146)
		row.detail:SetJustifyH("RIGHT")
		row.detail:SetWordWrap(false)
		row:SetScript("OnClick", function(button)
			local item = self.completion.items[self.completion.offset + button:GetID()]
			if item then
				self:InsertCompletion(item)
			end
		end)
		row:SetScript("OnEnter", function(button)
			self:ShowCompletionTooltip(self.completion.offset + button:GetID())
		end)
		row:SetScript("OnLeave", function()
			self:HideCompletionTooltip()
		end)
		self.popup.rows[index] = row
	end

	self.edit:SetScript("OnTextChanged", function(_, userInput)
		self.click = nil
		if self.setting then
			return
		end
		if userInput and self.onEdited then
			self.onEdited()
		end
		self:RefreshAll()
		if userInput then
			self:RefreshCompletions()
		else
			self:HideCompletion()
		end
	end)
	self.edit:SetScript("OnCursorChanged", function(_, x, y, width, height)
		self:OnCursorChanged(x, y, width, height)
	end)
	self.edit:SetScript("OnMouseDown", function(_, button)
		if button ~= "LeftButton" then
			self.click = nil
			return
		end
		local x, y = self:PointerPosition()
		self.click = {
			row = x and self:PointerRow(y) or nil,
		}
	end)
	self.edit:SetScript("OnMouseUp", function(_, button)
		if button ~= "LeftButton" then
			self.click = nil
			return
		end
		local x, y = self:PointerPosition()
		local row = x and self:PointerRow(y) or nil
		local left = self.edit:GetLeft()
		if not row or type(left) ~= "number" then
			self.click = nil
			return
		end
		-- The live position, not the row cached by the last OnCursorChanged: the client may report the cursor only
		-- after this release, so the cached row can still be the old one.
		local position = self.edit:GetCursorPosition()
		self:ReleaseClick(row, x - left, position and Editor.RowAtCursor(self.rows, position))
	end)
	self.edit:SetScript("OnEditFocusGained", function()
		self:UpdateHighlight()
	end)
	self.edit:SetScript("OnEditFocusLost", function()
		self.click = nil
		self:HideCompletion()
		self:StopCaret()
	end)
	self.edit:SetScript("OnArrowPressed", function(_, key)
		self.click = nil
		if not self.popup:IsShown() then
			return false
		end
		if key == "UP" then
			self:MoveCompletion(-1)
			return true
		elseif key == "DOWN" then
			self:MoveCompletion(1)
			return true
		end
		return false
	end)
	self.edit:SetScript("OnTabPressed", function()
		self.click = nil
		if self.popup:IsShown() then
			local item = self.completion.items[self.completion.selected]
			if item then
				self:InsertCompletion(item)
			end
			return true
		end
		local diagnostic = self:DiagnosticAt((self.edit:GetCursorPosition() or 0) + 1)
		if diagnostic and diagnostic.fix then
			self:ApplyFix(diagnostic)
			return true
		end
		return false
	end)
	self.edit:SetScript("OnEscapePressed", function()
		self.click = nil
		if self.popup:IsShown() then
			self:HideCompletion()
			return true
		end
		if self.onEscape then
			self.onEscape()
		end
		return true
	end)
	-- Home, End, Ctrl+End and every other key move the cursor themselves. A click still waiting for its own cursor
	-- update must not snap the cursor back afterwards, so the record goes as soon as any key is pressed.
	self.edit:SetScript("OnKeyDown", function()
		self.click = nil
	end)

	self:RefreshAll()
	return self
end

---@param text string
function Editor:SetText(text)
	self.setting = true
	self.edit:SetText(text or "")
	self.setting = false
	self.edit:SetCursorPosition(0)
	self:HideCompletion()
	self:RefreshAll()
end

---@return string
function Editor:GetText()
	return self.edit:GetText() or ""
end

function Editor:Focus()
	self.edit:SetFocus()
end

function Editor:ClearFocus()
	self.edit:ClearFocus()
end

---@param inCombat boolean
function Editor:SetCombat(inCombat)
	self.inCombat = inCombat
	self:UpdateStatus()
end

-- The pointer in the same UI units as the edit's GetTop and GetLeft. GetCursorPosition is in screen pixels, so it
-- is divided by the edit's effective scale before any row or character comparison.
---@return number? x
---@return number? y
function Editor:PointerPosition()
	local scale = self.edit:GetEffectiveScale()
	local x, y = GetCursorPosition()
	if type(x) ~= "number" or type(y) ~= "number" or type(scale) ~= "number" or scale <= 0 then
		return nil
	end
	return x / scale, y / scale
end

-- The visual row (1-based) under a pointer y, counted from the edit's own top edge in the same pitch as the text.
---@param y number?
---@return integer? rowIndex
function Editor:PointerRow(y)
	local top = self.edit:GetTop()
	if type(y) ~= "number" or type(top) ~= "number" or not self.lineHeight or self.lineHeight <= 0 then
		return nil
	end
	return math.floor((top - y) / self.lineHeight) + 1
end

-- One line's pitch from the font API: the measured line height plus the spacing SetSpacing adds, the same sum
-- Blizzard uses in SecureUtil's maxLines. The overlay, gutter, caret, highlight, squiggles and popup read this.
function Editor:UpdateLineHeight()
	local height = self.probe:GetLineHeight()
	local spacing = self.probe:GetSpacing()
	if type(height) == "number" and height > 0 then
		self.lineHeight = height + (type(spacing) == "number" and spacing or 0)
		self.caret:SetHeight(self.lineHeight)
	end
end

function Editor:UpdateMetrics()
	self:UpdateLineHeight()
end

-- The EditBox's own caret rect: x and y are offsets from its top-left, and h is one line tall. The caret uses them
-- verbatim, the current-line highlight takes its row from y, and a click waiting for the client's cursor lands here
-- because OnCursorChanged can arrive after OnMouseUp.
---@param x number?
---@param y number?
---@param width number?
---@param height number?
function Editor:OnCursorChanged(x, y, width, height)
	local row = nil
	if type(x) == "number" and type(y) == "number" then
		self.cursorX = x
		self.cursorY = y
		self.cursorWidth = type(width) == "number" and width or 0
		self.cursorHeight = type(height) == "number" and height > 0 and height or self.lineHeight
		self.cursorRow = math.floor(-y / self.lineHeight) + 1
		row = self.cursorRow
	end
	self:UpdateHighlight()
	self:ResolvePendingClick(row)
	self:UpdateDiagnosticTooltip()
	if self.popup:IsShown() then
		self:PositionPopup()
	end
end

-- The release half of the click rule: `upRow` is the row under the pointer on release, `x` its offset from the
-- edit's left edge, and `cursorRow` the visual row of the EditBox's live cursor position. The live row is used
-- rather than the cached one because the client may move its cursor after the release. When it cannot resolve the
-- click yet, the record waits for exactly one cursor update.
---@param upRow integer?
---@param x number?
---@param cursorRow integer?
function Editor:ReleaseClick(upRow, x, cursorRow)
	local click = self.click
	if not click or not upRow or upRow ~= click.row or not x then
		self.click = nil
		return
	end
	click.upRow = upRow
	click.x = x
	local target = cursorRow and Editor.ClickCursor(self.rows, click.row, upRow, cursorRow, x, self.textMeasure)
	if target then
		self.click = nil
		self:MoveCursor(target)
		return
	end
	click.pending = true
end

-- The cursor half of the click rule: the client may report its cursor only after the mouse release. A click that the
-- live position could not resolve gets one chance here, on the row the client's y reports, and is then dropped
-- whether or not it moved the cursor.
---@param cursorRow integer?
function Editor:ResolvePendingClick(cursorRow)
	local click = self.click
	if not click or not click.pending or self.resolvingClick then
		return
	end
	self.click = nil
	if not click.upRow or click.x == nil or not cursorRow then
		return
	end
	local target = Editor.ClickCursor(self.rows, click.row, click.upRow, cursorRow, click.x, self.textMeasure)
	if target then
		self:MoveCursor(target)
	end
end

-- Setting the cursor fires OnCursorChanged again; the flag keeps a click resolution from starting a second one.
---@param position integer
function Editor:MoveCursor(position)
	self.resolvingClick = true
	self.edit:SetCursorPosition(position)
	self.resolvingClick = false
end

function Editor:RefreshAll()
	if not self.textArea:GetWidth() or self.textArea:GetWidth() <= 1 then
		return
	end
	self:UpdateMetrics()
	self.wrapWidth = math.max(1, self.textArea:GetWidth() - TEXT_INSET_LEFT - TEXT_INSET_RIGHT)
	self.measure:SetWidth(self.wrapWidth)
	local text = self:GetText()
	local parsed = ns.Parser.Parse(text)
	self.parsed = parsed
	self.rows = Editor.LayoutRows(text, self.wrapWidth, self.lineHeight, self.textMeasure)
	self:LayoutLines(parsed)
	self.diagnostics = ns.Check(text, ns.Context.ctx)
	self:LayoutDiagnostics()
	self:UpdateHighlight()
	self:UpdateStatus()
end

-- One coloured FontString per logical line still wraps itself at the edit's width; the measured rows only place
-- its first row and its gutter number, and every later row shares the same pitch because they are the same rows.
---@param parsed MacroAssistParse
function Editor:LayoutLines(parsed)
	local lineTop = {}
	for _, row in ipairs(self.rows) do
		lineTop[row.line] = lineTop[row.line] or row.y
	end
	local used = 0
	for index, line in ipairs(parsed.lines) do
		local y = lineTop[index] or 0
		used = used + 1
		local font = self.lineFonts[used]
		if not font then
			font = self.overlay:CreateFontString(nil, "ARTWORK", "MacroAssistMono")
			font:SetJustifyH("LEFT")
			font:SetSpacing(LINE_SPACING)
			self.lineFonts[used] = font
		end
		font:SetWidth(self.wrapWidth)
		font:SetText(ns.Highlight.Line(line))
		font:SetPoint("TOPLEFT", self.overlay, "TOPLEFT", TEXT_INSET_LEFT, -(TEXT_INSET_TOP + y))
		font:Show()

		local number = self.numberFonts[index]
		if not number then
			number = self.gutter:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			number:SetJustifyH("RIGHT")
			number:SetWidth(GUTTER_WIDTH - 4)
			self.numberFonts[index] = number
		end
		number:SetText(tostring(index))
		number:SetTextColor(0.55, 0.55, 0.55)
		number:SetPoint("TOPLEFT", self.gutter, "TOPLEFT", 0, -y)
		number:Show()
	end
	for index = used + 1, #self.lineFonts do
		self.lineFonts[index]:Hide()
	end
	for index = #parsed.lines + 1, #self.numberFonts do
		self.numberFonts[index]:Hide()
	end
	self.contentHeight = #self.rows * self.lineHeight
end

---@param owner Frame
---@param diagnostic MacroAssistDiagnostic
---@param anchor string
local function ShowDiagnosticTooltip(owner, diagnostic, anchor)
	GameTooltip:SetOwner(owner, anchor)
	GameTooltip:SetText(diagnostic.message, 1, 1, 1, 1, true)
	if diagnostic.fix then
		GameTooltip:AddLine(L["Tab: fix"], 0.2, 1, 0.2, true)
	end
	GameTooltip:Show()
end

-- The squiggles never take the mouse: a click on their row must reach the EditBox. The cursor is the path to the
-- message, so moving it into a diagnostic shows the tooltip without an OnUpdate poll, and Tab applies the fix.
---@param position integer
---@return MacroAssistDiagnostic?
function Editor:DiagnosticAt(position)
	for _, diagnostic in ipairs(self.diagnostics or {}) do
		local from = diagnostic.from or 1
		local to = diagnostic.to or from
		if position >= from and position <= to + 1 then
			return diagnostic
		end
	end
end

function Editor:UpdateDiagnosticTooltip()
	local position = (self.edit:GetCursorPosition() or 0) + 1
	local diagnostic = self:DiagnosticAt(position)
	if diagnostic then
		ShowDiagnosticTooltip(self.edit, diagnostic, "ANCHOR_CURSOR")
	elseif GameTooltip:IsOwned(self.edit) then
		GameTooltip:Hide()
	end
end

-- One squiggle frame per visual row a diagnostic covers, measured from the same rows as the text so a wrapped
-- line's underline sits under its own words. Frames are mouse-transparent on purpose.
function Editor:LayoutDiagnostics()
	local used = 0
	for _, diagnostic in ipairs(self.diagnostics or {}) do
		local from = math.max(1, diagnostic.from or 1)
		local to = math.max(from, diagnostic.to or from)
		for _, row in ipairs(self.rows) do
			if row.to > row.from and to >= row.from and from < row.to then
				local startByte = math.max(from, row.from)
				local endByte = math.min(to, row.to - 1)
				local x1 = Editor.RowOffset(row, startByte - 1, self.textMeasure)
				local x2 = Editor.RowOffset(row, endByte, self.textMeasure)
				if x2 <= x1 then
					x2 = Editor.RowOffset(row, startByte, self.textMeasure)
				end
				used = used + 1
				local frame = self.squiggles[used]
				if not frame then
					frame = CreateFrame("Frame", nil, self.textArea) --[[@as MacroAssistSquiggle]]
					frame:SetFrameLevel(self.textArea:GetFrameLevel() + 4)
					frame:EnableMouse(false)
					frame.texture = frame:CreateTexture(nil, "ARTWORK")
					frame.texture:SetAllPoints(frame)
					frame.texture:SetTexture("Interface\\AddOns\\MacroAssistForever\\media\\squiggle")
					frame.texture:SetHorizTile(true)
					self.squiggles[used] = frame
				end
				frame:SetPoint(
					"BOTTOMLEFT",
					self.textArea,
					"TOPLEFT",
					TEXT_INSET_LEFT + x1,
					-(TEXT_INSET_TOP + row.y + self.lineHeight - 1)
				)
				frame:SetSize(x2 - x1, SQUIGGLE_HEIGHT)
				if diagnostic.severity == "error" then
					frame.texture:SetVertexColor(1, 0.25, 0.25, 0.95)
				else
					frame.texture:SetVertexColor(1, 0.82, 0.2, 0.95)
				end
				frame:Show()
			end
		end
	end
	for index = used + 1, #self.squiggles do
		self.squiggles[index]:Hide()
	end
end

-- The current-line highlight takes its row from the EditBox's cursor y, so it always covers the line the caret is
-- on, including a wrapped row the model-based column count used to miss.
function Editor:UpdateHighlight()
	local row = self.cursorRow and self.rows and self.rows[self.cursorRow]
	if not row or not self.cursorX or not self.cursorY then
		self.highlight:Hide()
		self:StopCaret()
		return
	end
	self.highlight:SetPoint("TOPLEFT", self.textArea, "TOPLEFT", TEXT_INSET_LEFT, -(TEXT_INSET_TOP + row.y))
	self.highlight:SetSize(self.wrapWidth, self.lineHeight)
	self.highlight:Show()
	self:PlaceCaret()
end

-- The caret sits exactly where the EditBox says its own caret is, one cursor rect tall. Its frame is above the
-- overlay so the white line stays visible over coloured text; the repeating AnimationGroup still owns the blink.
function Editor:PlaceCaret()
	if not self.cursorX or not self.cursorY then
		self:StopCaret()
		return
	end
	self.caret:ClearAllPoints()
	self.caret:SetPoint("TOPLEFT", self.edit, "TOPLEFT", self.cursorX, self.cursorY)
	self.caret:SetSize(1, self.cursorHeight or self.lineHeight)
	if not self.edit:HasFocus() then
		self:StopCaret()
		return
	end
	self.caret:Show()
	self.caret:SetAlpha(1)
	self.caretBlink:Stop()
	self.caretBlink:Play()
end

function Editor:StopCaret()
	if not self.caret then
		return
	end
	self.caretBlink:Stop()
	self.caret:Hide()
end

---@return string? now
---@return boolean hasCommands
function Editor:NowText()
	if type(SecureCmdOptionParse) ~= "function" or not self.parsed then
		return nil, false
	end
	local function evaluate(text)
		local ok, result = pcall(SecureCmdOptionParse, text)
		if ok then
			return result
		end
		return nil
	end
	local result, hasCommands, unit = ns.Now(self.parsed, evaluate)
	if result and unit and unit ~= "" and unit ~= "player" and unit ~= "none" then
		local name = ns.Readable(UnitName(unit))
		if name then
			result = result .. " " .. L["on %s"]:format(name)
		end
	end
	return result, hasCommands
end

function Editor:UpdateStatus()
	if not self.status then
		return
	end
	local problem
	if not self.diagnostics or #self.diagnostics == 0 then
		problem = COLOUR_GREEN .. L["No problems"] .. COLOUR_CLOSE
	else
		local count = #self.diagnostics
		local colour = self.diagnostics[1].severity == "error" and COLOUR_RED or COLOUR_YELLOW
		local phrase = count == 1 and L["%d problem · %s"] or L["%d problems · %s"]
		problem = colour .. phrase:format(count, self.diagnostics[1].message) .. COLOUR_CLOSE
	end
	local now, hasCommands = self:NowText()
	local nowText
	if now and now ~= "" then
		nowText = L["Now: %s"]:format(now)
	elseif hasCommands then
		nowText = COLOUR_MUTED .. L["Nothing fires now"] .. COLOUR_CLOSE
	else
		nowText = COLOUR_MUTED .. L["No commands in this macro yet."] .. COLOUR_CLOSE
	end
	local text = problem
		.. COLOUR_MUTED
		.. "  ·  "
		.. COLOUR_CLOSE
		.. nowText
		.. COLOUR_MUTED
		.. "  ·  "
		.. COLOUR_CLOSE
		.. COLOUR_YELLOW
		.. L["%d/%d"]:format(ns.Length(self:GetText()), ns.MacroLimit)
		.. COLOUR_CLOSE
	if self.inCombat then
		text = text .. COLOUR_RED .. "  ·  " .. L["Saving is disabled in combat."] .. COLOUR_CLOSE
	end
	self.status:SetText(text)
end

---@param diagnostic MacroAssistDiagnostic
function Editor:ApplyFix(diagnostic)
	if not diagnostic.fix then
		return
	end
	local text = self:GetText()
	local newText = Replace(text, diagnostic.fix.from, diagnostic.fix.to, diagnostic.fix.insert)
	self.setting = true
	self.edit:SetText(newText)
	self.setting = false
	self.edit:SetCursorPosition(diagnostic.fix.from + #diagnostic.fix.insert - 1)
	self.edit:SetFocus()
	self:HideCompletion()
	self:RefreshAll()
end

---@param index integer
function Editor:ShowCompletionTooltip(index)
	local item = self.completion.items[index]
	if not item then
		return
	end
	local row = self.popup.rows[index - self.completion.offset]
	if not row then
		return
	end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:SetText(item.label, 1, 1, 1, 1, true)
	if item.detail and item.detail ~= "" then
		GameTooltip:AddLine(item.detail, 1, 1, 1, true)
	end
	GameTooltip:AddLine(L["Tab to insert."], 0.2, 1, 0.6, true)
	GameTooltip:Show()
end

function Editor:HideCompletionTooltip()
	local owner = GameTooltip:GetOwner()
	if owner and owner:GetParent() == self.popup then
		GameTooltip:Hide()
	end
end

function Editor:HideCompletion()
	self.popup:Hide()
	self:HideCompletionTooltip()
end

---@param delta integer
function Editor:MoveCompletion(delta)
	local count = #self.completion.items
	if count == 0 then
		return
	end
	local selected = self.completion.selected + delta
	if selected < 1 then
		selected = count
	elseif selected > count then
		selected = 1
	end
	self.completion.selected = selected
	if selected <= self.completion.offset then
		self.completion.offset = selected - 1
	elseif selected > self.completion.offset + POPUP_ROWS then
		self.completion.offset = selected - POPUP_ROWS
	end
	self:RenderCompletion()
	self:ShowCompletionTooltip(selected)
end

---@param item MacroAssistCompletionItem
function Editor:InsertCompletion(item)
	local text = self:GetText()
	local newText = Replace(text, self.completion.from, self.completion.to, item.insert)
	self.setting = true
	self.edit:SetText(newText)
	self.setting = false
	self.edit:SetCursorPosition(self.completion.from + #item.insert - 1)
	self.edit:SetFocus()
	self:HideCompletion()
	self:RefreshAll()
end

function Editor:RefreshCompletions()
	if not self.textArea:GetWidth() or self.textArea:GetWidth() <= 1 then
		return
	end
	local text = self:GetText()
	local cursor = (self.edit:GetCursorPosition() or #text) + 1
	local result = ns.Complete(text, cursor, ns.Context.ctx)
	self.completion.items = result.items or {}
	self.completion.from = result.from or 1
	self.completion.to = result.to or 0
	self.completion.selected = 1
	self.completion.offset = 0
	if #self.completion.items == 0 then
		self:HideCompletion()
		return
	end
	self:RenderCompletion()
	self:PositionPopup()
	self.popup:Show()
	self:ShowCompletionTooltip(self.completion.selected)
end

function Editor:RenderCompletion()
	local items = self.completion.items
	local first = self.completion.offset + 1
	local last = math.min(#items, self.completion.offset + POPUP_ROWS)
	for index = 1, POPUP_ROWS do
		local row = self.popup.rows[index]
		local itemIndex = first + index - 1
		local item = itemIndex >= first and itemIndex <= last and items[itemIndex] or nil
		if item then
			row:SetID(index)
			row:Show()
			row.badge:SetText(BADGES[item.kind] or "?")
			row.label:SetText(item.label)
			if CODE_KINDS[item.kind] then
				row.label:SetFontObject(FONT_NAME)
			else
				row.label:SetFontObject("GameFontHighlight")
			end
			row.detail:SetText(item.detail or "")
			row.highlight:SetShown(itemIndex == self.completion.selected)
		else
			row:Hide()
		end
	end
	self.popup:SetHeight(math.max(1, last - first + 1) * POPUP_ROW_HEIGHT + POPUP_INSET_TOP + POPUP_INSET_BOTTOM)
end

function Editor:PositionPopup()
	local cursor = self.edit:GetCursorPosition() or 0
	local index = Editor.RowAtCursor(self.rows, cursor)
	local row = index and self.rows[index]
	if not row then
		return
	end
	local x = TEXT_INSET_LEFT + Editor.RowOffset(row, cursor, self.textMeasure)
	local y = TEXT_INSET_TOP + row.y + self.lineHeight
	local height = self.popup:GetHeight()
	local width = math.max(280, math.min(self.wrapWidth, 560))
	self.popup:SetWidth(width)
	self.popup:ClearAllPoints()
	if self.textArea:GetHeight() > 0 and y + height > self.textArea:GetHeight() then
		self.popup:SetPoint("BOTTOMLEFT", self.textArea, "TOPLEFT", x, -(y - self.lineHeight - 2))
	else
		self.popup:SetPoint("TOPLEFT", self.textArea, "TOPLEFT", x, -y - 2)
	end
end

ns.Editor = Editor
