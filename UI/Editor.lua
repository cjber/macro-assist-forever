local _, ns = ...

-- The macro editor: a real multi-line EditBox draws the caret and takes typing, while every visible string is an
-- overlay FontString built from ns.Highlight. The EditBox's own text is transparent, so colour codes never count
-- against its 255 letters. Gutter row counts come from a hidden FontString measured at the same width, never from a
-- second wrapping implementation.

local L = ns.L

local FONT_NAME = "MacroAssistMono"
local FONT_SIZE = 12
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
end

---@param text string
---@param from integer
---@param to integer
---@return string
local function Replace(text, from, to, insert)
	return text:sub(1, from - 1) .. insert .. text:sub(to + 1)
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
---@field diagnostic MacroAssistDiagnostic?

---@class MacroAssistEditorLine
---@field from integer
---@field to integer
---@field text string
---@field y number
---@field height number
---@field rows integer

---@class MacroAssistEditor
---@field parent Frame
---@field gutter Frame
---@field textArea Frame
---@field overlay Frame
---@field edit EditBox
---@field measure FontString
---@field probe FontString
---@field highlight Texture
---@field status FontString
---@field popup MacroAssistCompletionPopup
---@field lineFonts FontString[]
---@field numberFonts FontString[]
---@field squiggles MacroAssistSquiggle[]
---@field completion MacroAssistCompletionState
---@field layout MacroAssistEditorLine[]
---@field diagnostics MacroAssistDiagnostic[]
---@field parsed MacroAssistParse?
---@field hoveredDiagnostic MacroAssistDiagnostic?
---@field cursorLine MacroAssistEditorLine?
---@field cursorRow integer?
---@field advance number
---@field columns integer
---@field lineHeight number
---@field wrapWidth number
---@field setting boolean
---@field inCombat boolean
---@field onEdited? fun()
---@field onEscape? fun()
local Editor = {}

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
	self.edit:SetTextColor(1, 1, 1, 0)
	self.edit:SetJustifyH("LEFT")
	self.edit:SetFrameLevel(self.textArea:GetFrameLevel() + 3)

	self.measure = self.textArea:CreateFontString(nil, "ARTWORK", "MacroAssistMono")
	self.measure:SetJustifyH("LEFT")
	self.measure:SetAlpha(0)
	self.probe = self.textArea:CreateFontString(nil, "ARTWORK", "MacroAssistMono")
	self.probe:SetAlpha(0)
	self.probe:SetText(string.rep("M", 32))
	-- Measured, never assumed: a known run's width divided by its length gives the fixed advance.
	self.advance = self.probe:GetStringWidth() / 32
	if not self.advance or self.advance <= 0 then
		self.advance = 1
	end
	self.probe:SetText("")
	self.lineHeight = self.measure:GetLineHeight()
	if not self.lineHeight or self.lineHeight <= 0 then
		self.lineHeight = FONT_SIZE + 2
	end

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
	self.edit:SetScript("OnCursorChanged", function()
		self:UpdateHighlight()
		self:UpdateDiagnosticTooltip()
		if self.popup:IsShown() then
			self:PositionPopup()
		end
	end)
	self.edit:SetScript("OnEditFocusLost", function()
		self:HideCompletion()
	end)
	self.edit:SetScript("OnArrowPressed", function(_, key)
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
		if self.popup:IsShown() then
			local item = self.completion.items[self.completion.selected]
			if item then
				self:InsertCompletion(item)
			end
			return true
		end
		local diagnostic = self.hoveredDiagnostic
		if diagnostic and diagnostic.fix then
			self:ApplyFix(diagnostic)
			return true
		end
		return false
	end)
	self.edit:SetScript("OnEscapePressed", function()
		if self.popup:IsShown() then
			self:HideCompletion()
			return true
		end
		if self.onEscape then
			self.onEscape()
		end
		return true
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

-- The bundled mono font may still be resolving when the editor is created, so the probe's first width can be the
-- fallback font's advance. Measure again on every layout: one GetStringWidth, and the squiggle, popup and wrapping
-- column all use the advance the overlay and EditBox are actually drawing with.
function Editor:UpdateAdvance()
	self.probe:SetText(string.rep("M", 32))
	local width = self.probe:GetStringWidth()
	self.probe:SetText("")
	if type(width) == "number" and width > 0 then
		local advance = width / 32
		if advance > 0 then
			self.advance = advance
		end
	end
end

function Editor:RefreshAll()
	if not self.textArea:GetWidth() or self.textArea:GetWidth() <= 1 then
		return
	end
	self:UpdateAdvance()
	self.wrapWidth = math.max(1, self.textArea:GetWidth() - TEXT_INSET_LEFT - TEXT_INSET_RIGHT)
	self.columns = math.max(1, math.floor(self.wrapWidth / self.advance))
	local text = self:GetText()
	local parsed = ns.Parser.Parse(text)
	self.parsed = parsed
	self:LayoutLines(parsed)
	self.diagnostics = ns.Check(text, ns.Context.ctx)
	self:LayoutDiagnostics()
	self:UpdateHighlight()
	self:UpdateStatus()
end

---@param parsed MacroAssistParse
function Editor:LayoutLines(parsed)
	self.layout = {}
	self.measure:SetWidth(self.wrapWidth)
	self.measure:SetText("M")
	local lineHeight = self.measure:GetLineHeight()
	if lineHeight and lineHeight > 0 then
		self.lineHeight = lineHeight
	end
	local used = 0
	local y = 0
	for index, line in ipairs(parsed.lines) do
		self.measure:SetText(line.text ~= "" and line.text or "M")
		local rows = self.measure:GetNumLines()
		if not rows or rows < 1 then
			rows = 1
		end
		local height = self.measure:GetStringHeight()
		if not height or height < self.lineHeight then
			height = rows * self.lineHeight
		end
		used = used + 1
		local font = self.lineFonts[used]
		if not font then
			font = self.overlay:CreateFontString(nil, "ARTWORK", "MacroAssistMono")
			font:SetJustifyH("LEFT")
			self.lineFonts[used] = font
		end
		-- The EditBox wraps its own transparent text; this FontString wraps the coloured copy at the same font and
		-- width. Whether the two line up is an in-game check, not something a second wrapping implementation can prove.
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

		self.layout[index] = {
			from = line.from,
			to = line.to,
			text = line.text,
			y = y,
			height = height,
			rows = rows,
		}
		y = y + height
	end
	for index = used + 1, #self.lineFonts do
		self.lineFonts[index]:Hide()
	end
	for index = #parsed.lines + 1, #self.numberFonts do
		self.numberFonts[index]:Hide()
	end
	self.measure:SetText("")
	self.contentHeight = y
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

-- The EditBox sits above the squiggles and eats their mouse, so the caret is the path that always reaches the
-- message: moving it into a diagnostic shows the same tooltip, without an OnUpdate poll. The squiggle frames sit
-- above the EditBox so OnEnter can run; SetPropagateMouseClicks, which would pass a click through that strip, is a
-- protected function on this client, so it is not called. In game, check that a hover shows the tooltip and that a
-- click on the 4 px strip still lands in the text.
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
	if self.hoveredDiagnostic then
		return
	end
	local position = (self.edit:GetCursorPosition() or 0) + 1
	local diagnostic = self:DiagnosticAt(position)
	if diagnostic then
		ShowDiagnosticTooltip(self.edit, diagnostic, "ANCHOR_CURSOR")
	elseif GameTooltip:IsOwned(self.edit) then
		GameTooltip:Hide()
	end
end

-- One squiggle frame per visible diagnostic row. It sits above the EditBox, whose transparent text would otherwise
-- take the mouse, so OnEnter can show the message and OnMouseUp can apply the fix.
function Editor:LayoutDiagnostics()
	local used = 0
	for _, diagnostic in ipairs(self.diagnostics or {}) do
		local from = math.max(1, diagnostic.from or 1)
		local to = math.max(from, diagnostic.to or from)
		for _, layout in ipairs(self.layout) do
			if to >= layout.from and from <= layout.to then
				local startByte = math.max(from, layout.from)
				local endByte = math.min(to, layout.to)
				local startColumn = ns.Length(layout.text:sub(1, startByte - layout.from))
				local endColumn = startColumn
					+ ns.Length(layout.text:sub(startByte - layout.from + 1, endByte - layout.from + 1))
				if endColumn <= startColumn then
					endColumn = startColumn + 1
				end
				local firstRow = math.floor(startColumn / self.columns)
				local lastRow = math.floor((endColumn - 1) / self.columns)
				for row = firstRow, lastRow do
					local rowStart = row * self.columns
					local segmentFrom = math.max(startColumn, rowStart)
					local segmentTo = math.min(endColumn, rowStart + self.columns)
					if segmentTo > segmentFrom then
						used = used + 1
						local frame = self.squiggles[used]
						if not frame then
							frame = CreateFrame("Frame", nil, self.textArea) --[[@as MacroAssistSquiggle]]
							frame:SetFrameLevel(self.textArea:GetFrameLevel() + 4)
							frame:EnableMouse(true)
							frame.texture = frame:CreateTexture(nil, "ARTWORK")
							frame.texture:SetAllPoints(frame)
							frame.texture:SetTexture("Interface\\AddOns\\MacroAssistForever\\media\\squiggle")
							frame.texture:SetHorizTile(true)
							frame:SetScript("OnEnter", function(button)
								local current = button.diagnostic
								if not current then
									return
								end
								self.hoveredDiagnostic = current
								ShowDiagnosticTooltip(button, current, "ANCHOR_RIGHT")
							end)
							frame:SetScript("OnLeave", function(button)
								self.hoveredDiagnostic = nil
								if GameTooltip:IsOwned(button) then
									GameTooltip:Hide()
								end
								self:UpdateDiagnosticTooltip()
							end)
							frame:SetScript("OnMouseUp", function(button, mouseButton)
								if mouseButton == "LeftButton" and button.diagnostic and button.diagnostic.fix then
									self:ApplyFix(button.diagnostic)
								end
							end)
							self.squiggles[used] = frame
						end
						frame.diagnostic = diagnostic
						frame:SetPoint(
							"BOTTOMLEFT",
							self.textArea,
							"TOPLEFT",
							TEXT_INSET_LEFT + (segmentFrom - rowStart) * self.advance,
							-(TEXT_INSET_TOP + layout.y + row * self.lineHeight + self.lineHeight - 1)
						)
						frame:SetSize((segmentTo - segmentFrom) * self.advance, SQUIGGLE_HEIGHT)
						if diagnostic.severity == "error" then
							frame.texture:SetVertexColor(1, 0.25, 0.25, 0.95)
						else
							frame.texture:SetVertexColor(1, 0.82, 0.2, 0.95)
						end
						frame:Show()
					end
				end
			end
		end
	end
	for index = used + 1, #self.squiggles do
		self.squiggles[index]:Hide()
	end
	self.hoveredDiagnostic = nil
end

function Editor:UpdateHighlight()
	if not self.layout or #self.layout == 0 then
		return
	end
	local cursor = (self.edit:GetCursorPosition() or 0) + 1
	local layout
	for _, candidate in ipairs(self.layout) do
		if cursor >= candidate.from - 1 and cursor <= candidate.to then
			layout = candidate
			break
		end
	end
	if not layout then
		for _, candidate in ipairs(self.layout) do
			if cursor >= candidate.from then
				layout = candidate
			end
		end
	end
	if not layout then
		return
	end
	local column = ns.Length(layout.text:sub(1, math.max(0, cursor - layout.from)))
	local row = math.floor(column / self.columns)
	local y = layout.y + row * self.lineHeight
	self.highlight:SetPoint("TOPLEFT", self.textArea, "TOPLEFT", TEXT_INSET_LEFT, -(TEXT_INSET_TOP + y))
	self.highlight:SetSize(self.wrapWidth, self.lineHeight)
	self.highlight:Show()
	self.cursorLine = layout
	self.cursorRow = row
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
	local layout = self.cursorLine
	if not layout then
		return
	end
	local cursor = (self.edit:GetCursorPosition() or 0) + 1
	local column = ns.Length(layout.text:sub(1, math.max(0, cursor - layout.from)))
	local row = math.floor(column / self.columns)
	local x = TEXT_INSET_LEFT + (column - row * self.columns) * self.advance
	local y = TEXT_INSET_TOP + layout.y + row * self.lineHeight + self.lineHeight
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
