-- ForeverCore, the addon every Forever addon requires: where its checkout is, the way the specs and the sim find it.
-- FOREVER_CORE names it, else the sibling checkout ../forever-core; CI checks the ref in tools/forever-core.txt out
-- into forever-core/ and points the variable there. The simulator's own loader reads ForeverCore.toc and loads its
-- files in order, before the addon's, because the addon's TOC lists it in ## Dependencies.
local ForeverCore = {}

local DEFAULT_DIRECTORY = "../forever-core"

local function Exists(path)
	local file = io.open(path .. "/ForeverCore.toc", "r")
	if file then
		file:close()
		return true
	end
	return false
end

-- The checkout, as FOREVER_CORE names it. A relative path is read from the working directory first, then from
-- GITHUB_WORKSPACE, because the simulator may run from a scratch folder rather than the repository root.
---@return string
function ForeverCore.directory()
	local configured = os.getenv("FOREVER_CORE")
	local candidates = {}
	if configured and configured ~= "" then
		candidates[#candidates + 1] = configured
		if configured:sub(1, 1) ~= "/" then
			local workspace = os.getenv("GITHUB_WORKSPACE")
			if workspace and workspace ~= "" then
				candidates[#candidates + 1] = workspace .. "/" .. configured
			end
		end
	else
		candidates[#candidates + 1] = DEFAULT_DIRECTORY
	end
	for _, path in ipairs(candidates) do
		local cleaned = path:gsub("/+$", "")
		if cleaned ~= "" and Exists(cleaned) then
			return cleaned
		end
	end
	error(
		"ForeverCore's checkout is not at "
			.. table.concat(candidates, " or ")
			.. "; set FOREVER_CORE to it (tools/forever-core.txt names the ref)"
	)
end

-- ForeverCore as an extra addon for the client simulator: the folder and its addon name, registered next to the one
-- under test so the TOC's dependency resolves to the real checkout.
---@return { [1]: string, [2]: string }[]
function ForeverCore.addons()
	return { { ForeverCore.directory(), "ForeverCore" } }
end

return ForeverCore
