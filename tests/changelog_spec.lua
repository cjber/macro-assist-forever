-- Run from the repository root: luajit tests/changelog_spec.lua
-- A ForeverCore release re-releases every addon with a maintenance entry in CHANGELOG.md. It has no bold lead, so the
-- headline an in-game What's new line uses is the newest entry that has one. This addon has no such line today; the
-- spec pins the rule the suite's line follows, including a maintenance entry on top of a normal one.
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

-- Every `## [x.y.z] - YYYY-MM-DD` release and the body up to the next versioned heading.
local function Releases(text)
	local found = {}
	local nextSearch = 1
	while true do
		local start, finish, version = text:find("\n## %[(%d+%.%d+%.%d+)%] %- %d%d%d%d%-%d%d%-%d%d\n", nextSearch)
		if not start then
			return found
		end
		local following = text:find("\n## %[", finish + 1)
		found[#found + 1] = { version = version, body = text:sub(finish + 1, (following or #text + 1) - 1) }
		nextSearch = finish + 1
	end
end

-- The newest release with a `- **...**` lead, skipping a maintenance entry above it.
-- The packager ships text files with CRLF line endings, so the packaged CHANGELOG.md is read the same way.
local function Headline(text)
	for _, release in ipairs(Releases("\n" .. (text:gsub("\r\n", "\n")))) do
		local headline = release.body:match("%-%s*%*%*(.-)%*%*")
		if headline then
			return release.version, headline
		end
	end
end

-- A core sync's maintenance entry on top of a normal release: the normal release keeps the headline.
local maintenance = table.concat({
	"## [9.9.9] - 2026-11-12",
	"",
	"<!-- forever-core-sync -->",
	"",
	"- Ships with the same shared code as your other Forever addons, so they keep working together.",
	"",
	"## [9.9.8] - 2026-11-11",
	"",
	"- **A real headline.** What it says.",
}, "\n")
local maintenanceVersion, maintenanceHeadline = Headline(maintenance)
check(maintenanceVersion == "9.9.8", "a maintenance entry on top is skipped for the headline version")
check(maintenanceHeadline == "A real headline.", "a maintenance entry on top is skipped for the headline")

-- The real changelog has a release with a bold lead, so the suite's rule has something to name.
local changelog = assert(io.open("CHANGELOG.md")):read("*a")
local newestVersion, newestHeadline = Headline(changelog)
check(newestVersion ~= nil, "CHANGELOG.md has a release with a bold lead")
check(newestHeadline ~= nil and newestHeadline ~= "", "that release's lead is not empty")

print(("changelog_spec: %d checks passed"):format(checks))
