local _, ns = ...

if ns.broken then
	return
end

-- The Recipes popup: the general recipes and the player's class recipes, with the whole macro beside the list. A
-- recipe whose spells the player has not learned stays selectable so its macro can be read, but it is greyed, Import
-- is off, and the level comes only from the client. Import goes through the macro window's own write path, so the
-- length check, the slot limit, the history snapshot and the combat refusal are the same as every other write.

local L = ns.L

local WIDTH = 660
local HEIGHT = 420
-- PortraitFrameTemplate's TitleContainer starts 58 from the frame's left edge, which clears the 62-unit portrait
-- that starts 5 units outside it. The heading takes that inset so it has the native header text's clearance instead
-- of sitting under the portrait ring.
local HEADING_LEFT = 58
local HINT_TOP = 50
local HINT_HEIGHT = 34
local CONTENT_TOP = HINT_TOP + HINT_HEIGHT + 8
local BODY_INSET = 10
local PREVIEW_PADDING = 10
local LIST_WIDTH = 240
local GAP = 8
local INSET_PADDING = 6
local SCROLL_GAP = 4
local SCROLL_WIDTH = 8
local SCROLL_RIGHT_PADDING = 2
local ROW_HEIGHT = 34
local BUTTON_WIDTH = 90
local BUTTON_HEIGHT = 24
local BOTTOM = 8
local BOX_BOTTOM = 40
-- A wrapped row is drawn two mono cells in from the left, so a preview reads a real newline as the only thing that
-- starts at the left edge. The editor's own rows wrap at the same measured words; only the indent is the preview's.
local HANGING_INDENT = "  "

local MUTED = { 0.55, 0.55, 0.55 }
local ROW_MUTED = { 0.6, 0.6, 0.6 }
local RED = { 1, 0.25, 0.25 }

---@class MacroAssistRecipeRow : Button
---@field state MacroAssistRecipeState?
---@field Title FontString
---@field Note FontString
---@field Selected Texture
---@field SelectedBar Texture
---@field Highlight Texture

---@class MacroAssistRecipesPanel : Frame
---@field TitleContainer MacroAssistTitleContainer
---@field PortraitContainer MacroAssistPortraitContainer
---@field Inset Frame
---@field CloseButton Button
---@field heading FontString
---@field scrollBox MacroAssistScrollBox
---@field empty FontString
---@field preview ScrollFrame
---@field previewChild Frame
---@field previewText FontString
---@field previewValue string?
---@field textMeasure MacroAssistTextMeasure
---@field lineHeight number
---@field status FontString
---@field importButton Button
---@field onImport fun(body: string)
---@field states MacroAssistRecipeState[]
---@field selected MacroAssistRecipeState?
---@field selectedRecipe MacroAssistRecipe?
---@field combat boolean
---@field full boolean

local Panel = {}

---@param text string
---@return string
local function Escape(text)
	return (text:gsub("|", "||"))
end

-- The heading names the class whose recipes are listed, in the client's own language. Without a class it stays the
-- popup's own name, and the list still holds the recipes every class can use.
---@return string
local function Heading()
	if type(UnitClass) == "function" then
		local ok, name = pcall(UnitClass, "player")
		if ok and type(name) == "string" and name ~= "" then
			return L["%s recipes"]:format(name)
		end
	end
	return L["Recipes"]
end

-- The preview is a ScrollFrame so a long macro is still complete. The rows are the editor's own measured rows, drawn
-- into one FontString with a hanging indent on every row a wrap created: only a real newline starts at the left
-- edge, and the child's height gives the scroll range. No timer or OnUpdate is involved.
---@param frame MacroAssistRecipesPanel
function Panel.Measure(frame)
	local width = frame.preview:GetWidth()
	if type(width) ~= "number" or width <= 1 then
		return
	end
	local indent = frame.textMeasure.width(HANGING_INDENT)
	local rows = ns.Editor.LayoutRows(frame.previewValue or "", width, frame.lineHeight, frame.textMeasure, indent)
	local parts = {}
	for index, row in ipairs(rows) do
		parts[index] = row.row > 0 and (HANGING_INDENT .. row.text) or row.text
	end
	frame.previewChild:SetWidth(width)
	frame.previewText:SetWidth(width)
	frame.previewText:SetText(table.concat(parts, "\n"))
	frame.previewChild:SetHeight(math.max(1, #rows * frame.lineHeight))
	frame.preview:UpdateScrollChildRect()
	frame.preview:SetVerticalScroll(0)
end

---@param frame MacroAssistRecipesPanel
---@param row MacroAssistRecipeRow
---@param state MacroAssistRecipeState
local function PaintRow(frame, row, state)
	local selected = state == frame.selected
	row.Selected:SetShown(selected)
	row.SelectedBar:SetShown(selected)
	row.Title:SetText(L[state.recipe.title] or state.recipe.title)
	local note = ""
	if not state.available then
		note = state.level and L["Learn at level %d"]:format(state.level) or L["Not learned"]
	end
	row.Note:SetText(note)
	row.Note:SetTextColor(ROW_MUTED[1], ROW_MUTED[2], ROW_MUTED[3])
	if selected then
		row.Title:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	elseif state.available then
		row.Title:SetTextColor(1, 1, 1)
	else
		row.Title:SetTextColor(ROW_MUTED[1], ROW_MUTED[2], ROW_MUTED[3])
	end
	row.Highlight:Hide()
end

---@param frame MacroAssistRecipesPanel
local function UpdateStatus(frame)
	local state = frame.selected
	local canImport = state ~= nil and state.available and state.body ~= nil and not frame.combat and not frame.full
	frame.importButton:SetEnabled(canImport)
	if not state then
		frame.status:SetText(L["No recipe selected."])
		frame.status:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	elseif not state.body then
		frame.status:SetText(L["This recipe needs a spell this client does not know."])
		frame.status:SetTextColor(RED[1], RED[2], RED[3])
	elseif not state.available then
		frame.status:SetText(state.level and L["Learn at level %d."]:format(state.level) or L["Not learned."])
		frame.status:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	elseif frame.combat then
		frame.status:SetText(L["A macro can't be created, changed or deleted in combat."])
		frame.status:SetTextColor(RED[1], RED[2], RED[3])
	elseif frame.full then
		frame.status:SetText(L["No macro slots are free."])
		frame.status:SetTextColor(RED[1], RED[2], RED[3])
	else
		frame.status:SetText("")
	end
end

---@param frame MacroAssistRecipesPanel
local function ShowState(frame)
	local state = frame.selected
	if state and state.body then
		frame.previewValue = Escape(state.body)
		frame.previewText:SetTextColor(1, 1, 1)
	elseif state then
		frame.previewValue = L["This recipe needs a spell this client does not know."]
		frame.previewText:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	else
		frame.previewValue = L["No recipe selected."]
		frame.previewText:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	end
	Panel.Measure(frame)
	UpdateStatus(frame)
	frame.scrollBox:ForEachFrame(function(row)
		---@cast row MacroAssistRecipeRow
		if row.state then
			PaintRow(frame, row, row.state)
		end
	end)
end

---@param frame MacroAssistRecipesPanel
---@param state MacroAssistRecipeState?
function Panel.Select(frame, state)
	if state == frame.selected then
		return
	end
	frame.selected = state
	frame.selectedRecipe = state and state.recipe or nil
	ShowState(frame)
end

---@param frame MacroAssistRecipesPanel
---@param row MacroAssistRecipeRow
---@param data table
function Panel.InitializeRow(frame, row, data)
	row.state = data.state
	PaintRow(frame, row, data.state)
	row:SetScript("OnClick", function()
		Panel.Select(frame, data.state)
	end)
	row:SetScript("OnEnter", function()
		row.Highlight:Show()
	end)
	row:SetScript("OnLeave", function()
		row.Highlight:Hide()
	end)
end

-- Rebuild the list from the client. A recipe that was selected stays selected even when it becomes unavailable, so
-- its greyed row and level stay in view; otherwise the first available recipe is opened.
---@param frame MacroAssistRecipesPanel
function Panel.Refresh(frame)
	local states = ns.Context.RecipeStates()
	frame.states = states
	local selected
	for _, state in ipairs(states) do
		if frame.selectedRecipe and state.recipe == frame.selectedRecipe then
			selected = state
			break
		end
	end
	if not selected then
		for _, state in ipairs(states) do
			if state.available then
				selected = state
				break
			end
		end
	end
	selected = selected or states[1]
	frame.selected = selected
	frame.selectedRecipe = selected and selected.recipe or nil
	local provider = CreateDataProvider() --[[@as DataProviderMixin]]
	for _, state in ipairs(states) do
		provider:Insert({ state = state })
	end
	frame.scrollBox:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
	frame.empty:SetShown(#states == 0)
	ShowState(frame)
end

---@param parent Frame
---@param onImport fun(body: string)
---@return MacroAssistRecipesPanel
function Panel.Create(parent, onImport)
	local frame = CreateFrame("Frame", nil, parent, "ButtonFrameTemplate") --[[@as MacroAssistRecipesPanel]]
	frame:Hide()
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
	frame:SetFrameStrata("DIALOG")
	frame:SetFrameLevel(parent:GetFrameLevel() + 40)
	frame:SetClampedToScreen(true)
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame.TitleContainer.TitleText:SetText(L["Recipes"])
	frame.PortraitContainer.portrait:SetTexture(ns.Icon)
	frame.Inset:Hide()
	frame.CloseButton:SetScript("OnClick", function()
		Panel.Close(frame)
	end)
	frame.onImport = onImport
	frame.states = {}
	frame.combat = false
	frame.full = false

	local heading = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	heading:SetPoint("TOPLEFT", frame, "TOPLEFT", HEADING_LEFT, -HINT_TOP)
	heading:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -HINT_TOP)
	heading:SetJustifyH("LEFT")
	heading:SetWordWrap(false)
	frame.heading = heading

	local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -(HINT_TOP + 18))
	hint:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -(HINT_TOP + 18))
	hint:SetJustifyH("LEFT")
	hint:SetWordWrap(false)
	hint:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	hint:SetText(L["Choose a recipe to preview its macro."])

	local list = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	list:SetPoint("TOPLEFT", frame, "TOPLEFT", BODY_INSET, -CONTENT_TOP)
	list:SetSize(LIST_WIDTH, HEIGHT - CONTENT_TOP - BOX_BOTTOM)

	-- The rows fill the whole inset, so a selected row reaches its right edge as the client's own lists do. The
	-- scrollbar sits over the row's last few units instead of taking a gutter out of the row, and the row's text
	-- keeps clear of it.
	local scrollBox = CreateFrame("Frame", nil, list, "WowScrollBoxList") --[[@as MacroAssistScrollBox]]
	scrollBox:SetPoint("TOPLEFT", list, "TOPLEFT", INSET_PADDING, -INSET_PADDING)
	scrollBox:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -INSET_PADDING, INSET_PADDING)
	local scrollBar = CreateFrame("EventFrame", nil, list, "MinimalScrollBar")
	scrollBar:SetPoint("TOPRIGHT", list, "TOPRIGHT", -(INSET_PADDING + SCROLL_RIGHT_PADDING), -INSET_PADDING)
	scrollBar:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -(INSET_PADDING + SCROLL_RIGHT_PADDING), INSET_PADDING)
	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	view:SetElementInitializer("MacroAssistRecipeRowTemplate", function(row, data)
		---@cast row MacroAssistRecipeRow
		Panel.InitializeRow(frame, row, data)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox --[[@as ScrollBoxListMixin]], scrollBar, view)
	frame.scrollBox = scrollBox

	local empty = list:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	empty:SetPoint("CENTER", list, "CENTER", 0, 0)
	empty:SetText(L["No recipes yet."])
	empty:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	empty:Hide()
	frame.empty = empty

	local previewInset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	previewInset:SetPoint("TOPLEFT", list, "TOPRIGHT", GAP, 0)
	previewInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -BODY_INSET, BOX_BOTTOM)

	local preview = CreateFrame("ScrollFrame", nil, previewInset)
	preview:SetPoint("TOPLEFT", previewInset, "TOPLEFT", PREVIEW_PADDING, -PREVIEW_PADDING)
	preview:SetPoint(
		"BOTTOMRIGHT",
		previewInset,
		"BOTTOMRIGHT",
		-(SCROLL_WIDTH + SCROLL_GAP + PREVIEW_PADDING),
		PREVIEW_PADDING
	)
	local previewBar = CreateFrame("EventFrame", nil, previewInset, "MinimalScrollBar")
	previewBar:SetPoint("TOPLEFT", preview, "TOPRIGHT", SCROLL_GAP, 0)
	previewBar:SetPoint("BOTTOMLEFT", preview, "BOTTOMRIGHT", SCROLL_GAP, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(preview, previewBar)
	local previewChild = CreateFrame("Frame", nil, preview)
	previewChild:SetWidth(1)
	previewChild:SetHeight(1)
	preview:SetScrollChild(previewChild)
	local previewText = previewChild:CreateFontString(nil, "ARTWORK", "MacroAssistMono")
	previewText:SetPoint("TOPLEFT", previewChild, "TOPLEFT", 0, 0)
	previewText:SetWidth(1)
	previewText:SetJustifyH("LEFT")
	previewText:SetJustifyV("TOP")
	-- The rows are already wrapped at the editor's measured words, so the FontString must not wrap them again; a
	-- token wider than a row was broken by the layout itself.
	previewText:SetWordWrap(false)
	-- A hidden copy of the same font object measures a row and the hanging indent, exactly as the editor does.
	local previewMeasure = previewChild:CreateFontString(nil, "ARTWORK", "MacroAssistMono")
	previewMeasure:SetAlpha(0)
	previewMeasure:SetWordWrap(false)
	frame.textMeasure = {
		width = function(value)
			previewMeasure:SetText(value)
			local width = previewMeasure:GetStringWidth()
			previewMeasure:SetText("")
			return type(width) == "number" and width or 0
		end,
	}
	frame.lineHeight = ns.Editor.LineHeight
	frame.preview = preview
	frame.previewChild = previewChild
	frame.previewText = previewText
	preview:SetScript("OnSizeChanged", function()
		Panel.Measure(frame)
	end)

	local status = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	status:SetPoint("LEFT", frame, "LEFT", 12, BOTTOM + BUTTON_HEIGHT / 2)
	status:SetPoint("RIGHT", frame, "RIGHT", -10 - BUTTON_WIDTH - GAP, BOTTOM + BUTTON_HEIGHT / 2)
	status:SetJustifyH("LEFT")
	status:SetWordWrap(false)
	frame.status = status

	local import = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate")
	import:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
	import:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, BOTTOM)
	import:SetText(L["Import"])
	import:SetScript("OnClick", function()
		local state = frame.selected
		if not state or not state.available or not state.body or frame.combat or frame.full then
			return
		end
		local body = state.body or ""
		Panel.Close(frame)
		if frame.onImport then
			frame.onImport(body)
		end
	end)
	frame.importButton = import

	frame:SetScript("OnShow", function()
		Panel.Measure(frame)
	end)
	return frame
end

---@param frame MacroAssistRecipesPanel
---@param combat boolean
---@param full boolean
function Panel.Open(frame, combat, full)
	frame.combat = combat == true
	frame.full = full == true
	frame.selectedRecipe = nil
	frame.heading:SetText(Heading())
	frame:Show()
	Panel.Refresh(frame)
	Panel.Measure(frame)
end

---@param frame MacroAssistRecipesPanel
function Panel.Close(frame)
	frame:Hide()
end

-- Combat and a full macro store leave the list readable but turn Import off, exactly as the Import box does. The
-- spellbook itself is refreshed by Panel.Refresh from the window's SPELLS_CHANGED branch.
---@param frame MacroAssistRecipesPanel
---@param combat boolean
---@param full boolean
function Panel.SetState(frame, combat, full)
	frame.combat = combat == true
	frame.full = full == true
	if frame:IsShown() then
		UpdateStatus(frame)
	end
end

ns.RecipesPanel = {
	Create = Panel.Create,
	Open = Panel.Open,
	Close = Panel.Close,
	Refresh = Panel.Refresh,
	SetState = Panel.SetState,
}
