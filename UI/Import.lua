local _, ns = ...

if ns.broken then
	return
end

-- The Import box. Addons cannot reach wago.io or another character's macros, so the only way in is a paste. The
-- panel classifies the text and runs the same parser and checks the editor uses; Import is live only for a macro that
-- fits the 255-character limit. Creating the macro and opening the icon picker are the window's job.

local L = ns.L

local WIDTH = 440
local HEIGHT = 400
local INSET_PADDING = 6
local BUTTON_WIDTH = 90
local BUTTON_HEIGHT = 24
local BOTTOM = 8
local HINT_TOP = 50
local HINT_HEIGHT = 34
local BOX_BOTTOM = 76
local STATUS_BOTTOM = 48

local MUTED = { 0.55, 0.55, 0.55 }
local RED = { 1, 0.25, 0.25 }
local GREEN = { 0.2, 1, 0.6 }
local YELLOW = { 1, 0.82, 0.2 }

---@class MacroAssistImportPanel : Frame
---@field TitleContainer MacroAssistTitleContainer
---@field PortraitContainer MacroAssistPortraitContainer
---@field Inset Frame
---@field CloseButton Button
---@field inset Frame
---@field edit EditBox
---@field status FontString
---@field length FontString
---@field importButton Button
---@field cancelButton Button
---@field onImport fun(body: string)
---@field combat boolean

local Panel = {}

---@param parent Frame
---@param onImport fun(body: string)
---@return MacroAssistImportPanel
function Panel.Create(parent, onImport)
	local frame = CreateFrame("Frame", nil, parent, "ButtonFrameTemplate") --[[@as MacroAssistImportPanel]]
	frame:Hide()
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
	frame:SetFrameStrata("DIALOG")
	frame:SetFrameLevel(parent:GetFrameLevel() + 40)
	frame:SetClampedToScreen(true)
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame.TitleContainer.TitleText:SetText(L["Import macro"])
	frame.PortraitContainer.portrait:SetTexture(ns.Icon)
	frame.Inset:Hide()
	frame.CloseButton:SetScript("OnClick", function()
		Panel.Close(frame)
	end)
	frame.onImport = onImport
	frame.combat = false

	local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -HINT_TOP)
	hint:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -HINT_TOP)
	hint:SetHeight(HINT_HEIGHT)
	hint:SetJustifyH("LEFT")
	hint:SetJustifyV("TOP")
	hint:SetWordWrap(true)
	hint:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	hint:SetText(L["Paste a macro from wago.io or another character."])

	local inset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -(HINT_TOP + HINT_HEIGHT + 8))
	inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, BOX_BOTTOM)
	frame.inset = inset

	local edit = CreateFrame("EditBox", nil, inset)
	edit:SetPoint("TOPLEFT", inset, "TOPLEFT", INSET_PADDING + 2, -(INSET_PADDING + 2))
	edit:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -(INSET_PADDING + 2), INSET_PADDING + 2)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject("GameFontHighlight")
	edit:SetTextInsets(0, 0, 0, 0)
	edit:SetJustifyH("LEFT")
	edit:SetJustifyV("TOP")
	edit:SetScript("OnTextChanged", function()
		Panel.Refresh(frame)
	end)
	edit:SetScript("OnEscapePressed", function()
		Panel.Close(frame)
	end)
	frame.edit = edit

	local status = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	status:SetPoint("LEFT", frame, "LEFT", 12, STATUS_BOTTOM)
	status:SetPoint("RIGHT", frame, "RIGHT", -110, STATUS_BOTTOM)
	status:SetJustifyH("LEFT")
	status:SetWordWrap(false)
	frame.status = status

	local length = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	length:SetPoint("RIGHT", frame, "RIGHT", -12, STATUS_BOTTOM)
	length:SetJustifyH("RIGHT")
	length:SetWordWrap(false)
	frame.length = length

	local importButton = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate")
	importButton:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
	importButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, BOTTOM)
	importButton:SetText(L["Import"])
	importButton:SetScript("OnClick", function()
		if frame.combat then
			return
		end
		local classified = ns.Import.Classify(frame.edit:GetText())
		if classified.kind ~= "macro" or ns.Length(classified.body) > ns.MacroLimit then
			return
		end
		Panel.Close(frame)
		if frame.onImport then
			frame.onImport(classified.body)
		end
	end)
	frame.importButton = importButton

	local cancel = CreateFrame("Button", nil, frame, "SharedButtonSmallTemplate")
	cancel:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
	cancel:SetPoint("RIGHT", importButton, "LEFT", -6, 0)
	cancel:SetText(L["Cancel"])
	cancel:SetScript("OnClick", function()
		Panel.Close(frame)
	end)
	frame.cancelButton = cancel

	return frame
end

-- What the box says about the text in it: nothing pasted, prose, a MySlot export, or a macro with its first problem.
-- The counter and the checks measure the normalized body, the text the macro store takes, so Windows line endings do
-- not count as characters the saved macro will not have.
function Panel.Refresh(frame)
	local text = frame.edit:GetText() or ""
	local classified = ns.Import.Classify(text)
	local body = classified.body
	local length = ns.Length(body)
	frame.length:SetText(L["%d/%d"]:format(length, ns.MacroLimit))
	frame.length:SetTextColor(
		length > ns.MacroLimit and RED[1] or MUTED[1],
		length > ns.MacroLimit and RED[2] or MUTED[2],
		length > ns.MacroLimit and RED[3] or MUTED[3]
	)
	local ready = classified.kind == "macro" and length <= ns.MacroLimit and not frame.combat
	if frame.combat then
		frame.status:SetText(L["A macro can't be created, changed or deleted in combat."])
		frame.status:SetTextColor(RED[1], RED[2], RED[3])
	elseif classified.kind == "empty" then
		frame.status:SetText(L["Paste a macro to import."])
		frame.status:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
	elseif classified.kind == "myslot" then
		frame.status:SetText(L["This is a MySlot export, not a macro."])
		frame.status:SetTextColor(RED[1], RED[2], RED[3])
	elseif classified.kind == "text" then
		frame.status:SetText(L["Not a macro: no line starts with / or #."])
		frame.status:SetTextColor(RED[1], RED[2], RED[3])
	elseif length > ns.MacroLimit then
		frame.status:SetText(L["Macro is %d characters; the limit is %d."]:format(length, ns.MacroLimit))
		frame.status:SetTextColor(RED[1], RED[2], RED[3])
	else
		local diagnostics = ns.Check(body, ns.Context.ctx)
		if #diagnostics == 0 then
			frame.status:SetText(L["Ready to import."])
			frame.status:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
		else
			local first = diagnostics[1]
			local phrase = #diagnostics == 1 and L["%d problem · %s"] or L["%d problems · %s"]
			frame.status:SetText(phrase:format(#diagnostics, first.message))
			if first.severity == "error" then
				frame.status:SetTextColor(RED[1], RED[2], RED[3])
			else
				frame.status:SetTextColor(YELLOW[1], YELLOW[2], YELLOW[3])
			end
		end
	end
	frame.importButton:SetEnabled(ready)
end

function Panel.Open(frame)
	frame.edit:SetText("")
	frame.edit:SetFocus()
	frame:Show()
	Panel.Refresh(frame)
end

function Panel.Close(frame)
	frame.edit:ClearFocus()
	frame:Hide()
end

---@param combat boolean
function Panel.SetCombat(frame, combat)
	frame.combat = combat
	if frame:IsShown() then
		Panel.Refresh(frame)
	end
end

ns.ImportPanel = {
	Create = Panel.Create,
	Open = Panel.Open,
	Close = Panel.Close,
	Refresh = Panel.Refresh,
	SetCombat = Panel.SetCombat,
}
