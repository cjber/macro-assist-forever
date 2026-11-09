---@meta

-- FrameXML globals absent from Ketho's pinned Core and FrameXML annotations.
-- These declarations never load in the client.
---@type string[]
UISpecialFrames = {}

-- The saved table Core/Core.lua fills from ns.DEFAULTS.
---@class MacroAssistSaved
---@field font string
---@field showLineNumbers boolean
---@field completions boolean
---@field liveValues boolean
---@field diagnostics boolean
---@type MacroAssistSaved
MacroAssistForeverDB = nil
