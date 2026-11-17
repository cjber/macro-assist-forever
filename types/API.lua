---@meta

-- Macro Assist Forever's public API (version 1), read by other addons: the macro engine the editor runs on. Every member
-- is pure, reading only its arguments and the addon's bundled data. A table answer is fresh on every call, and a wrong
-- argument answers nil, "invalid". The answer shapes are Core/Parser.lua's, Core/Check.lua's and Core/Complete.lua's.

---@class MacroAssistAPISpell
---@field name string
---@field ranks? integer[] the ranks the player knows; `rank` names a single one
---@field rank? integer
---@field learned? boolean false for a spell the player has not learned; true when absent

---@class MacroAssistAPICheckContext
---@field spells? (string|MacroAssistAPISpell)[] the player's spells; without it no spell is judged
---@field items? table<any, string|boolean|{ name: string }> item names, as a list or a map, a /cast line may name instead

---@class MacroAssistAPIMember
---@field name string
---@field className? string shown as the completion's detail

---@class MacroAssistAPIRecipe
---@field title string
---@field body string the whole macro the completion inserts
---@field words? string[] intent words the typed text is matched against
---@field spells? string[] localized names of the spells it casts, matched too

---@class MacroAssistAPICondition
---@field name string the condition's lower-case name, without a no prefix
---@field no boolean true for the no form

---@class MacroAssistAPICompleteContext
---@field spells? (string|MacroAssistAPISpell)[] offered as /cast arguments, with their ranks
---@field members? MacroAssistAPIMember[] group members offered as names
---@field recipes? MacroAssistAPIRecipe[] whole macros offered for plain words
---@field evaluate? fun(condition: MacroAssistAPICondition): any a condition's live value, shown with tostring

---@class MacroAssistForeverAPI
---@field version integer
---@field minor integer raised with each addition; docs/api.md keeps the history
---@field Parse fun(body: string): MacroAssistParse?, ForeverCoreAPIInvalid? the body's lines, clauses and syntax diagnostics
---@field Check fun(body: string, context?: MacroAssistAPICheckContext): MacroAssistDiagnostic[]?, ForeverCoreAPIInvalid? every diagnostic, sorted by byte offset
---@field Explain fun(body: string): string?, ForeverCoreAPIInvalid? the macro in plain words; "" when there is nothing to say
---@field Length fun(body: string): integer?, ForeverCoreAPIInvalid? the characters the macro window counts
---@field MacroLimit fun(): integer the most characters a macro may hold
---@field Complete fun(body: string, cursor?: integer, context?: MacroAssistAPICompleteContext): MacroAssistCompletion?, ForeverCoreAPIInvalid? the completions at byte `cursor`

---@class MacroAssistForeverPublic
---@field API MacroAssistForeverAPI
---@type MacroAssistForeverPublic
MacroAssistForever = nil
