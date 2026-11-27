---@meta

-- FrameXML globals absent from Ketho's pinned Core and FrameXML annotations.
-- These declarations never load in the client.
---@type string[]
UISpecialFrames = {}

-- The annotations declare these two with no argument. Like GetMacroIcons, each appends file names to the table
-- it is given, as Blizzard's IconDataProvider calls them.
---@param files (string|number)[]
function GetLooseMacroIcons(files) end
---@param files (string|number)[]
function GetLooseMacroItemIcons(files) end

-- The input style API that tells us whether the gamepad interface is up.
C_InputInterfaceStyle = nil

-- The saved table Core/Core.lua fills from ns.DEFAULTS.
---@class MacroAssistSaved
---@field font string
---@field showLineNumbers boolean
---@field completions boolean
---@field liveValues boolean
---@field diagnostics boolean
---@field history table<string, MacroAssistHistoryRecord>
---@field characters? table<string, table>
---@field position? { x: number, y: number } The macro window's top left, from UIParent's top left, once moved
---@type MacroAssistSaved
MacroAssistForeverDB = nil

-- Localized slash commands supplied by the client's GlobalStrings table.
---@type string?
SLASH_USE1 = nil
---@type string?
SLASH_EQUIP1 = nil
---@type string?
SLASH_CAST1 = nil
