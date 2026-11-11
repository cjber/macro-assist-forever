local _, ns = ...

if ns.broken then
	return
end

-- Our icon picker: a grid in the code surface's rectangle, not Blizzard's popup. Clicking the header icon or Rename
-- swaps the editor for it. The grid is one ScrollBox of rows: a section heading then the icons that belong to it.
-- Every frame and field here is ours; the icon data comes from the client's provider, created and released per open.

local L = ns.L
local Icons = ns.Icons

local PICKER_PADDING = 12
local SEARCH_HEIGHT = 20
local SEARCH_GAP = 10
local ROW_TOP_GAP = 12
local ICON_SIZE = 36
local ICON_GAP = 5
local ICON_PITCH = ICON_SIZE + ICON_GAP
local ICON_ROW_HEIGHT = ICON_PITCH
local SECTION_HEIGHT = 24
local MAX_COLUMNS = 24
local SCROLL_GAP = 4
local SCROLL_WIDTH = 18
local AUTOMATIC_ICON = 134400
---@diagnostic disable-next-line: undefined-global
local GREEN = type(GREEN_FONT_COLOR_CODE) == "string" and GREEN_FONT_COLOR_CODE or "|cff1eff00"
local RESET = type(FONT_COLOR_CODE_CLOSE) == "string" and FONT_COLOR_CODE_CLOSE or "|r"

local SHOWS = { "all", "macro", "spellbook", "equipped" }

-- Filter labels. Core/Icons.lua owns the tokens; the words a player reads are here.
local SHOW_LABELS = {
	all = "All icons",
	macro = "From this macro",
	spellbook = "Spellbook",
	equipped = "Equipped and bags",
}
local CLASS_LABELS = {
	warrior = "Warrior",
	paladin = "Paladin",
	hunter = "Hunter",
	rogue = "Rogue",
	priest = "Priest",
	deathknight = "Death knight",
	shaman = "Shaman",
	mage = "Mage",
	warlock = "Warlock",
	monk = "Monk",
	druid = "Druid",
	demonhunter = "Demon hunter",
	evoker = "Evoker",
}
local SCHOOL_LABELS = {
	physical = "Physical",
	holy = "Holy",
	fire = "Fire",
	nature = "Nature",
	frost = "Frost",
	shadow = "Shadow",
	arcane = "Arcane",
}
local SLOT_LABELS = {
	head = "Head",
	chest = "Chest",
	hands = "Hands",
	weapons = "Weapons",
	shields = "Shields",
	jewelry = "Rings and trinkets",
	consumables = "Potions and food",
}

---@class MacroAssistIconButton : Button
---@field Icon Texture
---@field Gold Texture
---@field Highlight Texture
---@field Label FontString
---@field picker MacroAssistIconPicker
---@field entry table?

---@class MacroAssistFilterDropdown : Button
---@field Text FontString
---@field SetupMenu fun(self: MacroAssistFilterDropdown, generator: function)
---@field SetText fun(self: MacroAssistFilterDropdown, text: string)

---@class MacroAssistIconRow : Frame
---@field Title FontString
---@field Note FontString
---@field buttons MacroAssistIconButton[]

---@class MacroAssistIconPicker : Frame
---@field SetBackdrop fun(self: MacroAssistIconPicker, backdrop: table)
---@field SetBackdropColor fun(self: MacroAssistIconPicker, r: number, g: number, b: number, a: number)
---@field SetBackdropBorderColor fun(self: MacroAssistIconPicker, r: number, g: number, b: number, a: number)
---@field searchBox MacroAssistSearchBox
---@field dropdown MacroAssistFilterDropdown
---@field editor MacroAssistEditor
---@field scrollBox MacroAssistScrollBox
---@field scrollBar Frame
---@field statusFrame Frame
---@field statusText FontString
---@field statusKeep FontString
---@field selectedIcon any
---@field allIcons table[]?
---@field allRows table<integer, table[]>?
---@field kindCache table<string, { icons: table[], rows: table<integer, table[]> }>?
---@field show string
---@field kind table?
---@field search string
---@field onPick fun(icon: any)?
---@field onEscape fun()?
local Picker = {}

---@param parent Frame
---@param surface Frame
---@param editor MacroAssistEditor
---@return MacroAssistIconPicker
function Picker.Create(parent, surface, editor)
	local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate") --[[@as MacroAssistIconPicker]]
	for name, method in pairs(Picker) do
		if type(method) == "function" and name ~= "Create" then
			frame[name] = method
		end
	end
	frame:Hide()
	frame:SetPoint("TOPLEFT", surface, "TOPLEFT", 0, 0)
	frame:SetPoint("BOTTOMRIGHT", surface, "BOTTOMRIGHT", 0, 0)
	frame:SetFrameLevel(surface:GetFrameLevel() + 2)
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		tile = false,
		edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 },
	})
	frame:SetBackdropColor(0.035, 0.035, 0.04, 0.94)
	frame:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
	frame.show = "all"
	frame.search = ""
	frame.editor = editor

	local searchBox = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate") --[[@as MacroAssistSearchBox]]
	searchBox:SetHeight(SEARCH_HEIGHT)
	searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", PICKER_PADDING, -PICKER_PADDING)
	searchBox.Instructions:SetText(L["Search icons, spells and items"])
	searchBox:HookScript("OnTextChanged", function(edit)
		frame:SetSearch(edit:GetText() or "")
	end)
	searchBox:SetScript("OnEscapePressed", function()
		if frame.onEscape then
			frame.onEscape()
		end
	end)
	frame.searchBox = searchBox

	local dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1FilterDropdownTemplate")
	---@cast dropdown MacroAssistFilterDropdown
	frame.dropdown = dropdown
	-- The template's 18-unit button sits on the picker's top right; its label is centred below.
	frame.dropdown:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PICKER_PADDING, -PICKER_PADDING)
	-- The template's 20-unit box hangs the label 1 unit low on the 18-unit button: centre it on the art.
	frame.dropdown.Text:ClearAllPoints()
	frame.dropdown.Text:SetPoint("TOP", frame.dropdown, "TOP", 0, 1)
	frame.dropdown.Text:SetJustifyH("CENTER")
	frame.dropdown:SetupMenu(function(_, root)
		frame:BuildMenu(root)
	end)

	local scrollBox = CreateFrame("Frame", nil, frame, "WowScrollBoxList") --[[@as MacroAssistScrollBox]]
	scrollBox:SetPoint("TOPLEFT", frame, "TOPLEFT", PICKER_PADDING, -(PICKER_PADDING + SEARCH_HEIGHT + ROW_TOP_GAP))
	scrollBox:SetPoint(
		"BOTTOMRIGHT",
		frame,
		"BOTTOMRIGHT",
		-(SCROLL_WIDTH + SCROLL_GAP + PICKER_PADDING),
		PICKER_PADDING
	)
	local scrollBar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", SCROLL_GAP, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", SCROLL_GAP, 0)
	local view = CreateScrollBoxListLinearView()
	---@cast view ScrollBoxListLinearViewMixin
	view:SetElementExtentCalculator(function(_, data)
		return data.height
	end)
	view:SetElementInitializer("MacroAssistIconRowTemplate", function(row, data)
		---@cast row MacroAssistIconRow
		frame:InitializeRow(row, data)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox --[[@as ScrollBoxListMixin]], scrollBar, view)
	frame.scrollBox = scrollBox
	frame.scrollBar = scrollBar

	-- The picker's status strip covers the editor's: what the selected icon is, and how to keep it.
	local statusFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate") --[[@as Frame]]
	statusFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, -22)
	statusFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, -22)
	statusFrame:SetHeight(22)
	statusFrame:SetFrameLevel(frame:GetFrameLevel() + 4)
	local background = statusFrame:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints(statusFrame)
	background:SetColorTexture(0, 0, 0, 0.35)
	local rule = statusFrame:CreateTexture(nil, "BORDER")
	rule:SetColorTexture(1, 1, 1, 0.08)
	rule:SetPoint("TOPLEFT", statusFrame, "TOPLEFT", 0, 0)
	rule:SetPoint("TOPRIGHT", statusFrame, "TOPRIGHT", 0, 0)
	rule:SetHeight(1)
	local keep = statusFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	keep:SetPoint("RIGHT", statusFrame, "RIGHT", -10, 0)
	keep:SetJustifyH("RIGHT")
	keep:SetWordWrap(false)
	keep:SetText(L["Click to pick, Save to keep"])
	keep:SetTextColor(0.55, 0.55, 0.55)
	frame.statusKeep = keep
	local statusText = statusFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	statusText:SetPoint("LEFT", statusFrame, "LEFT", 10, 0)
	-- The right hint stays on its own edge, so the left text ends before it instead of running underneath.
	statusText:SetPoint("RIGHT", keep, "LEFT", -8, 0)
	statusText:SetJustifyH("LEFT")
	statusText:SetWordWrap(false)
	frame.statusText = statusText
	frame.statusFrame = statusFrame

	local lastWidth
	frame:SetScript("OnSizeChanged", function(_, width)
		if width > 1 and width ~= lastWidth then
			lastWidth = width
			frame:Layout()
		end
	end)

	return frame
end

---@param row MacroAssistIconRow
---@param data table
function Picker:InitializeRow(row, data)
	if not row.buttons then
		row.buttons = {}
		for index = 1, MAX_COLUMNS do
			local button = CreateFrame("Button", nil, row, "MacroAssistIconTemplate") --[[@as MacroAssistIconButton]]
			button:SetScript("OnClick", function(clicked)
				---@cast clicked MacroAssistIconButton
				if clicked.entry then
					clicked.picker:Pick(clicked.entry.icon)
				end
			end)
			button:SetScript("OnEnter", function(clicked)
				---@cast clicked MacroAssistIconButton
				clicked.Highlight:Show()
				clicked.picker:ShowTooltip(clicked)
			end)
			button:SetScript("OnLeave", function(clicked)
				---@cast clicked MacroAssistIconButton
				clicked.Highlight:Hide()
				if GameTooltip:IsOwned(clicked) then
					GameTooltip:Hide()
				end
			end)
			button.picker = self
			row.buttons[index] = button
		end
	end
	if data.kind == "header" then
		row.Title:Show()
		row.Title:SetText(data.title or "")
		row.Note:SetShown((data.note or "") ~= "")
		row.Note:SetText(data.note or "")
		for _, button in ipairs(row.buttons) do
			button:Hide()
		end
		return
	end
	row.Title:Hide()
	row.Note:Hide()
	for index, button in ipairs(row.buttons) do
		local entry = data.icons[index]
		if entry then
			button.entry = entry
			button.Icon:SetTexture(entry.icon)
			button.Icon:SetTexCoord(ns.ICON_TEXCOORD[1], ns.ICON_TEXCOORD[2], ns.ICON_TEXCOORD[3], ns.ICON_TEXCOORD[4])
			button.Gold:SetShown(Icons.Same(entry.icon, self.selectedIcon))
			button.Label:SetText(entry.auto and L["Auto"] or "")
			button.Label:SetShown(entry.auto == true)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", row, "TOPLEFT", (index - 1) * ICON_PITCH - 2, 2)
			button.Highlight:Hide()
			button:Show()
		else
			button.entry = nil
			button:Hide()
		end
	end
end

---@param _ MacroAssistIconPicker
---@param button MacroAssistIconButton
function Picker.ShowTooltip(_, button)
	local entry = button.entry
	if not entry then
		return
	end
	local name = Icons.FileName(entry.icon) or L["Unknown icon"]
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	if entry.label and entry.label ~= "" then
		GameTooltip:SetText(entry.label, 1, 1, 1, 1, true)
		GameTooltip:AddLine(name, 0.6, 0.6, 0.6, true)
	else
		GameTooltip:SetText(name, 1, 1, 1, 1, true)
	end
	GameTooltip:Show()
end

-- The client's entire icon list. The provider is created and released here, so no menu is left holding its tables.
---@return table[]
function Picker:AllIcons()
	if not self.allIcons then
		self.allIcons = {}
		local provider = CreateAndInitFromMixin(IconDataProviderMixin, IconDataProviderExtraType.None)
		for index = 2, provider:GetNumIcons() do
			local icon = provider:GetIconByIndex(index)
			if icon ~= nil then
				self.allIcons[#self.allIcons + 1] = { icon = icon }
			end
		end
		provider:Release()
	end
	return self.allIcons
end

-- Appends an entry unless its icon is already listed: each picker section shows an icon once.
---@param out table[]
---@param seen table
---@param entry table?
local function AddUnique(out, seen, entry)
	if entry and entry.icon ~= nil and not seen[entry.icon] then
		seen[entry.icon] = true
		out[#out + 1] = entry
	end
end

-- One entry per known spell, with the icon the button owns; a spell the client gives no texture for is left out.
---@return table[]
function Picker.SpellbookIcons(_)
	local out, seen = {}, {}
	for _, spell in ipairs(ns.Context.ctx.spells or {}) do
		AddUnique(out, seen, { icon = spell.icon, label = spell.name })
	end
	return out
end

-- Equipped items and everything in the player's bags, for the "Equipped and bags" source.
---@return table[]
function Picker.EquippedIcons(_)
	local out, seen = {}, {}
	for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
		local link = GetInventoryItemLink("player", slot)
		local name = link and C_Item.GetItemInfo(link)
		AddUnique(out, seen, { icon = GetInventoryItemTexture("player", slot), label = ns.Readable(name) })
	end
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info then
				AddUnique(out, seen, { icon = info.iconFileID, label = ns.Readable(info.itemName) })
			end
		end
	end
	return out
end

-- The client name for one spell or item a macro names: a spell first, then an item, as the macro APIs resolve them.
---@param name string
---@return table?
function Picker.Resolve(name)
	local ok, info = pcall(C_Spell.GetSpellInfo, name)
	if ok and type(info) == "table" and info.iconID then
		return { icon = info.iconID, label = ns.Readable(info.name) or name, kind = "spell" }
	end
	local itemOk, _, _, _, _, icon = pcall(C_Item.GetItemInfoInstant, name)
	if itemOk and icon then
		return { icon = icon, label = name, kind = "item" }
	end
end

-- The player's own spells and items, for the "Your spells" search section: the spellbook first, then anything the
-- macro names that the book does not list (an item, a rank the book hides).
---@param spellbook table[]?
---@return table[]
function Picker:Known(spellbook)
	local out, seen = {}, {}
	for _, entry in ipairs(spellbook or self:SpellbookIcons()) do
		AddUnique(out, seen, entry)
	end
	for _, entry in ipairs(self.macroIcons or {}) do
		AddUnique(out, seen, entry)
	end
	return out
end

---@param icon any
---@return string?
function Picker:LabelFor(icon)
	if Icons.Same(icon, AUTOMATIC_ICON) then
		return L["Automatic"]
	end
	if self.labels[icon] then
		return self.labels[icon]
	end
	-- A saved macro may hold its icon as a path while the lists hold FileDataIDs: the same file is the same icon.
	for listed, label in pairs(self.labels) do
		if Icons.Same(listed, icon) then
			return label
		end
	end
end

-- Keep the client's names for the icons the picker has listed, so the status strip can name any of them later.
---@param list table[]
function Picker:Remember(list)
	for _, entry in ipairs(list) do
		if entry.label and entry.label ~= "" and not self.labels[entry.icon] then
			self.labels[entry.icon] = entry.label
		end
	end
end

---@param text string
function Picker:SetSearch(text)
	local search = type(text) == "string" and text or ""
	if search == self.search then
		return
	end
	self.search = search
	self:Refresh()
end

---@param show string
function Picker:SetShow(show)
	if show == self.show then
		return
	end
	self.show = show
	self:Refresh()
	self:UpdateFilterText()
end

---@param kind string?
---@param token string?
function Picker:SetKind(kind, token)
	if kind == nil then
		self.kind = nil
	else
		self.kind = { kind = kind, token = token }
	end
	self:Refresh()
	self:UpdateFilterText()
end

---@return string
function Picker:KindLabel()
	local kind = self.kind
	if not kind then
		return ""
	end
	if kind.kind == "class" then
		return L[CLASS_LABELS[kind.token]] or kind.token
	elseif kind.kind == "school" then
		return L[SCHOOL_LABELS[kind.token]] or kind.token
	end
	return L[SLOT_LABELS[kind.token]] or kind.token
end

function Picker:UpdateFilterText()
	local text = self:KindLabel()
	if text == "" then
		text = L[SHOW_LABELS[self.show]] or L["All icons"]
	end
	self.dropdown:SetText(text)
	local width = self:GetWidth() - PICKER_PADDING * 2 - self.dropdown:GetWidth() - SEARCH_GAP
	self.searchBox:SetWidth(math.max(80, width))
end

---@param icons table[]
---@param kind table?
---@return table[]
function Picker:FilterKind(icons, kind)
	kind = kind or self.kind
	if not kind then
		return icons
	end
	local out = {}
	for _, entry in ipairs(icons) do
		local entryKind, token = Icons.Kind(Icons.FileName(entry.icon))
		if entryKind == kind.kind and token == kind.token then
			out[#out + 1] = entry
		end
	end
	return out
end

---@param entry table
---@return string?
function Picker.EntryName(_, entry)
	if not entry.name then
		entry.name = Icons.FileName(entry.icon)
	end
	return entry.name
end

---@param rows table[]
---@param title string
---@param note string?
local function AddHeader(rows, title, note)
	rows[#rows + 1] = { kind = "header", title = title, note = note or "", height = SECTION_HEIGHT }
end

---@param rows table[]
---@param icons table[]
---@param columns integer
local function AddIconRows(rows, icons, columns)
	for start = 1, #icons, columns do
		local slice = {}
		for index = start, math.min(start + columns - 1, #icons) do
			slice[#slice + 1] = icons[index]
		end
		rows[#rows + 1] = { kind = "icons", icons = slice, height = ICON_ROW_HEIGHT }
	end
end

-- The All icons section runs to every client icon, and its rows depend only on the column count and kind filter.
-- Building it once and reusing the row tables keeps a reopen from walking the whole icon list again.
---@param columns integer
---@return table[] rows
function Picker:AllIconRows(columns)
	self.allRows = self.allRows or {}
	local rows = self.allRows[columns]
	if not rows then
		rows = {}
		AddIconRows(rows, self:AllIcons(), columns)
		self.allRows[columns] = rows
	end
	return rows
end

-- The kind filter's icon list and rows are cached together: filtering every client icon is the other all-icon walk.
---@param kind table
---@return { icons: table[], rows: table<integer, table[]> }
function Picker:KindIcons(kind)
	self.kindCache = self.kindCache or {}
	local key = kind.kind .. ":" .. kind.token
	local cached = self.kindCache[key]
	if not cached then
		cached = { icons = self:FilterKind(self:AllIcons(), kind), rows = {} }
		self.kindCache[key] = cached
	end
	return cached
end

---@param columns integer
---@param kind table
---@return table[] rows
---@return integer count
function Picker:KindIconRows(columns, kind)
	local cached = self:KindIcons(kind)
	local rows = cached.rows[columns]
	if not rows then
		rows = {}
		AddIconRows(rows, cached.icons, columns)
		cached.rows[columns] = rows
	end
	return rows, #cached.icons
end

-- The row list for the current search and filter: the search's own spells first, then the source's name matches;
-- without a search, the three sections the picker opens with, or just the chosen source. Only the All icons rows
-- are cached; the macro and spellbook sections stay small and are rebuilt from the current macro.
---@return table[]
function Picker:BuildRows()
	local rows = {}
	local columns = self.columns or 1
	local search = self.search
	if search ~= "" then
		local spellbook = self:SpellbookIcons()
		local known = self:Known(spellbook)
		self:Remember(known)
		local source
		if self.show == "macro" then
			source = self.macroIcons or {}
		elseif self.show == "spellbook" then
			source = spellbook
		elseif self.show == "equipped" then
			source = self:EquippedIcons()
		elseif self.kind ~= nil then
			source = self:KindIcons(self.kind).icons
		else
			source = self:AllIcons()
		end
		if self.show ~= "all" then
			source = self:FilterKind(source)
		end
		for _, entry in ipairs(source) do
			self:EntryName(entry)
		end
		local spells, matches = Icons.Search(known, source, search)
		local labels = {}
		for _, entry in ipairs(spells) do
			labels[#labels + 1] = entry.label or ""
		end
		local note = table.concat(labels, ", ")
		if #labels > 3 then
			note = L["%s +%d"]:format(table.concat(labels, ", ", 1, 3), #labels - 3)
		end
		AddHeader(rows, L["Your spells"], note)
		AddIconRows(rows, spells, columns)
		local count = #matches
		local countText = count == 1 and L["%d match"]:format(count) or L["%d matches"]:format(count)
		AddHeader(rows, self:SourceTitle(), countText)
		AddIconRows(rows, matches, columns)
		return rows
	end
	if self.show == "all" and self.kind == nil then
		local spellbook = self:SpellbookIcons()
		self:Remember(spellbook)
		local fromMacro = { { icon = AUTOMATIC_ICON, label = L["Automatic"], auto = true } }
		for _, entry in ipairs(self.macroIcons or {}) do
			fromMacro[#fromMacro + 1] = entry
		end
		AddHeader(rows, L["From this macro"])
		AddIconRows(rows, fromMacro, columns)
		AddHeader(rows, L["Spellbook"], ns.Readable(self.className) or "")
		AddIconRows(rows, spellbook, columns)
		AddHeader(rows, L["All icons"], BreakUpLargeNumbers(#self:AllIcons()))
		for _, row in ipairs(self:AllIconRows(columns)) do
			rows[#rows + 1] = row
		end
		return rows
	end
	if self.show == "all" then
		local iconRows, count = self:KindIconRows(columns, self.kind)
		AddHeader(rows, self:SourceTitle(), BreakUpLargeNumbers(count))
		for _, row in ipairs(iconRows) do
			rows[#rows + 1] = row
		end
		return rows
	end
	local source
	if self.show == "macro" then
		source = self.macroIcons or {}
	elseif self.show == "spellbook" then
		source = self:SpellbookIcons()
	else
		source = self:EquippedIcons()
	end
	source = self:FilterKind(source)
	self:Remember(source)
	AddHeader(rows, self:SourceTitle(), BreakUpLargeNumbers(#source))
	AddIconRows(rows, source, columns)
	return rows
end

---@return string
function Picker:SourceTitle()
	if self.show == "macro" then
		return L["From this macro"]
	elseif self.show == "spellbook" then
		return L["Spellbook"]
	elseif self.show == "equipped" then
		return L["Equipped and bags"]
	end
	return L["All icons"]
end

function Picker:Refresh()
	if not self:IsShown() and not self.body then
		return
	end
	local width = self.scrollBox:GetWidth()
	if not width or width <= 1 then
		width = (self:GetWidth() or 1) - PICKER_PADDING * 2 - (SCROLL_WIDTH + SCROLL_GAP)
	end
	self.columns = math.max(1, math.floor((width + ICON_GAP) / ICON_PITCH))
	local rows = self:BuildRows()
	self.rows = rows
	local provider = CreateDataProvider() --[[@as DataProviderMixin]]
	for _, row in ipairs(rows) do
		provider:Insert(row)
	end
	self.scrollBox:SetDataProvider(provider)
	self.scrollBox:ScrollToBegin(true)
	self:UpdateFilterText()
	self:UpdateStatus()
end

-- A size change re-flows the grid, so only re-insert when the column count actually moved.
function Picker:Layout()
	if not self.body or self.columns == nil then
		return
	end
	local width = self.scrollBox:GetWidth() or 0
	local columns = width > 1 and math.max(1, math.floor((width + ICON_GAP) / ICON_PITCH)) or self.columns
	if columns == self.columns then
		self:UpdateFilterText()
		return
	end
	self.columns = columns
	self:Refresh()
end

function Picker:UpdateStatus()
	local icon = self.selectedIcon
	if Icons.Same(icon, AUTOMATIC_ICON) then
		local target = Icons.TooltipTarget(self.body or "")
		if not target then
			target = self.editor:NowRaw()
		end
		if target and target ~= "" then
			self.statusText:SetText(
				GREEN
					.. L["Automatic"]
					.. RESET
					.. " "
					.. L["shows the icon of the spell #showtooltip picks: %s"]:format(target)
			)
		else
			self.statusText:SetText(GREEN .. L["Automatic"] .. RESET .. " " .. L["shows the macro's own icon"])
		end
		return
	end
	local label = self:LabelFor(icon)
	self.statusText:SetText(label or Icons.FileName(icon) or L["Unknown icon"])
end

---@param icon any
function Picker:SetSelected(icon)
	self.selectedIcon = icon
	self.scrollBox:ForEachFrame(function(row)
		---@cast row MacroAssistIconRow
		for _, button in ipairs(row.buttons or {}) do
			if button.entry then
				button.Gold:SetShown(Icons.Same(button.entry.icon, icon))
			end
		end
	end)
	self:UpdateStatus()
end

---@param icon any
function Picker:Pick(icon)
	self:SetSelected(icon)
	if self.onPick then
		self.onPick(icon)
	end
end

---@param icon any
---@param body string?
---@param className string?
function Picker:Open(icon, body, className)
	self.body = body or ""
	self.className = className
	self.macroIcons = Icons.Actions(self.body, Picker.Resolve)
	self.search = ""
	self.show = "all"
	self.kind = nil
	self.selectedIcon = icon
	-- Only the player's own spells and this macro's actions are remembered up front; the All icons labels are read
	-- when a button is shown, hovered or searched, never by walking the whole client list on open.
	self.labels = {}
	self:Remember(self:Known())
	self.searchBox:SetText("")
	self.columns = nil
	self:Show()
	self:Refresh()
	self.searchBox:SetFocus()
end

function Picker:Close()
	self.body = nil
	GameTooltip:Hide()
	self:Hide()
end

---@param root any
function Picker:BuildMenu(root)
	root:SetScrollMode(300)
	root:CreateTitle(L["Show"])
	for _, show in ipairs(SHOWS) do
		root:CreateRadio(L[SHOW_LABELS[show]], function()
			return self.show == show
		end, function()
			self:SetShow(show)
		end)
	end
	root:CreateDivider()
	root:CreateTitle(L["Kind"])
	local all = L["All"]
	local classes = root:CreateButton(L["Class"])
	classes:SetScrollMode(300)
	classes:CreateRadio(all, function()
		return self.kind == nil or self.kind.kind ~= "class"
	end, function()
		self:SetKind(nil)
	end)
	for _, token in ipairs(Icons.ClassOrder) do
		classes:CreateRadio(L[CLASS_LABELS[token]], function()
			return self.kind ~= nil and self.kind.kind == "class" and self.kind.token == token
		end, function()
			self:SetKind("class", token)
		end)
	end
	local schools = root:CreateButton(L["Spell school"])
	schools:SetScrollMode(300)
	schools:CreateRadio(all, function()
		return self.kind == nil or self.kind.kind ~= "school"
	end, function()
		self:SetKind(nil)
	end)
	for _, token in ipairs(Icons.SchoolOrder) do
		schools:CreateRadio(L[SCHOOL_LABELS[token]], function()
			return self.kind ~= nil and self.kind.kind == "school" and self.kind.token == token
		end, function()
			self:SetKind("school", token)
		end)
	end
	local slots = root:CreateButton(L["Item slot"])
	slots:SetScrollMode(300)
	slots:CreateRadio(all, function()
		return self.kind == nil or self.kind.kind ~= "slot"
	end, function()
		self:SetKind(nil)
	end)
	for _, token in ipairs(Icons.SlotOrder) do
		slots:CreateRadio(L[SLOT_LABELS[token]], function()
			return self.kind ~= nil and self.kind.kind == "slot" and self.kind.token == token
		end, function()
			self:SetKind("slot", token)
		end)
	end
end

ns.IconPicker = Picker
