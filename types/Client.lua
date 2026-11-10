---@meta

-- FrameXML globals absent from Ketho's pinned Core and FrameXML annotations.
-- These declarations never load in the client.
---@type string[]
UISpecialFrames = {}

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
---@type MacroAssistSaved
MacroAssistForeverDB = nil
