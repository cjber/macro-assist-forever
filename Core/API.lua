local _, ns = ...

if ns.broken then
	return
end

-- MacroAssistForever.API, version 1: the macro engine the editor runs on, for other addons. Every member is pure: it
-- reads only its arguments and this addon's bundled command and condition data, never the client, so it answers the
-- same at load as in combat. A read that returns a table builds a fresh one on every call (docs/api.md).

-- Core/Require.lua refuses a core without these members before this file loads.
local APIKit = assert(ForeverCore.APIKit)
local Invalid = APIKit.Invalid

---@class MacroAssistForeverAPI
local API = {}
API.version = 1
API.minor = 0

-- A copy of an engine answer with no table shared with the engine or an earlier answer. A table the answer reaches
-- twice (a token in a line and in its clause) is copied once, so the copy keeps the answer's shape.
---@param value any
---@param copies table<table, table>?
---@return any
local function Copy(value, copies)
	if type(value) ~= "table" then
		return value
	end
	copies = copies or {}
	if copies[value] then
		return copies[value]
	end
	local copy = {}
	copies[value] = copy
	for key, inner in pairs(value) do
		copy[Copy(key, copies)] = Copy(inner, copies)
	end
	return copy
end

-- Validate the documented nested shapes before handing them to the pure engine. Its internal callers already
-- supply these shapes; public callers must receive an invalid answer rather than a Lua error for a malformed row.
---@param value any
---@return boolean
local function Rank(value)
	return type(value) == "number" and value > 0 and value < math.huge and value % 1 == 0
end

---@param values any
---@param valid fun(value: any): boolean
---@return boolean
local function List(values, valid)
	if values == nil then
		return true
	end
	if type(values) ~= "table" then
		return false
	end
	-- Distinct positive integer keys form 1..n exactly when their count equals the largest. The # operator
	-- can't decide this: on a table with holes it may return any border.
	local count, last = 0, 0
	for key, value in pairs(values) do
		if not Rank(key) or not valid(value) then
			return false
		end
		count = count + 1
		if key > last then
			last = key
		end
	end
	return count == last
end

---@param value any
---@return boolean
local function Text(value)
	return type(value) == "string"
end

---@param value any
---@return boolean
local function Spell(value)
	if Text(value) then
		return true
	end
	return type(value) == "table"
		and Text(value.name)
		and (value.learned == nil or type(value.learned) == "boolean")
		and (value.rank == nil or Rank(value.rank))
		and List(value.ranks, Rank)
end

---@param value any
---@return boolean
local function Member(value)
	return type(value) == "table" and Text(value.name) and (value.className == nil or Text(value.className))
end

---@param value any
---@return boolean
local function Recipe(value)
	return type(value) == "table"
		and Text(value.title)
		and Text(value.body)
		and List(value.words, Text)
		and List(value.spells, Text)
end

---@param values any
---@return boolean
local function Items(values)
	if type(values) ~= "table" then
		return false
	end
	for key, value in pairs(values) do
		if not (Text(key) or Rank(key)) then
			return false
		end
		if not Text(value) and not (type(value) == "table" and Text(value.name)) then
			if not (Text(key) and type(value) == "boolean") then
				return false
			end
		end
	end
	return true
end

local validators = {
	spells = function(value)
		return List(value, Spell)
	end,
	members = function(value)
		return List(value, Member)
	end,
	recipes = function(value)
		return List(value, Recipe)
	end,
	items = Items,
}

-- The engine context from a caller's: only the documented fields, each the right type, or nil for a wrong one. A
-- live value function sees a fresh `{ name, no }` per condition, never the addon's own condition data.
---@param context any
---@param fields string[]
---@return table?
local function Context(context, fields)
	if context == nil then
		return {}
	end
	if type(context) ~= "table" then
		return nil
	end
	local ctx = {}
	for _, field in ipairs(fields) do
		if field == "evaluate" then
			local evaluate = context.evaluate
			if evaluate ~= nil and type(evaluate) ~= "function" then
				return nil
			end
			if evaluate then
				ctx.evaluate = function(value)
					return evaluate({ name = value.name, no = value.no })
				end
			end
		elseif context[field] == nil or validators[field](context[field]) then
			ctx[field] = context[field]
		else
			return nil
		end
	end
	return ctx
end

-- The parse tree of a macro body: its lines, each line's command, clauses, condition groups and arguments with byte
-- ranges, and the syntax diagnostics.
---@param body string
---@return MacroAssistParse?, ForeverCoreAPIInvalid?
function API.Parse(body)
	if type(body) ~= "string" then
		return Invalid()
	end
	return Copy(ns.Parser.Parse(body))
end

-- Every diagnostic the editor underlines, sorted by byte offset. `context.spells` and `context.items` name what the
-- player knows, so a spell they lack is reported; without them no spell or item is judged.
---@param body string
---@param context? MacroAssistAPICheckContext
---@return MacroAssistDiagnostic[]?, ForeverCoreAPIInvalid?
function API.Check(body, context)
	local ctx = Context(context, { "spells", "items" })
	if type(body) ~= "string" or not ctx then
		return Invalid()
	end
	return Copy(ns.Check(body, ctx))
end

-- The macro in plain words, as the macro list shows it; an empty string when there is nothing to say.
---@param body string
---@return string?, ForeverCoreAPIInvalid?
function API.Explain(body)
	if type(body) ~= "string" then
		return Invalid()
	end
	return ns.Explain(body)
end

-- The count the macro window's counter shows: characters, not bytes, with every newline counting one.
---@param body string
---@return integer?, ForeverCoreAPIInvalid?
function API.Length(body)
	if type(body) ~= "string" then
		return Invalid()
	end
	return ns.Length(body)
end

-- The most characters a macro may hold.
---@return integer
function API.MacroLimit()
	return ns.MacroLimit
end

-- The completions for the caret at byte `cursor` (default: the end): replacing bytes `from`..`to` with an item's
-- `insert` makes the edit.
---@param body string
---@param cursor? integer
---@param context? MacroAssistAPICompleteContext
---@return MacroAssistCompletion?, ForeverCoreAPIInvalid?
function API.Complete(body, cursor, context)
	if type(body) ~= "string" then
		return Invalid()
	end
	if cursor == nil then
		cursor = #body + 1
	elseif type(cursor) ~= "number" or cursor ~= math.floor(cursor) or cursor < 1 or cursor > #body + 1 then
		return Invalid()
	end
	local ctx = Context(context, { "spells", "members", "recipes", "evaluate" })
	if not ctx then
		return Invalid()
	end
	return Copy(ns.Complete(body, cursor, ctx))
end

MacroAssistForever = MacroAssistForever or {}
MacroAssistForever.API = API
APIKit.Publish("MacroAssistForever", API)
