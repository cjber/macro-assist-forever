local _, ns = ...

---@type table<string, string | boolean>
ns.L = {
	["Macro Assist Forever"] = true,
	["Macro Assist Forever report"] = true,

	-- Forever Core's shared report and debug log.
	["Bug"] = true,
	["Bug: "] = true,
	["Copy issue link"] = true,
	["Copy report"] = true,
	["Feature request"] = true,
	["Feature request: "] = true,
	["Report a bug or request a feature"] = true,
	["Title"] = true,
	["What happened, or what you would like"] = true,
	["The link is selected. Press Ctrl+C (Cmd+C on a Mac), then paste into a browser; GitHub opens a filled-in issue."] = true,
	["The text is selected. Press Ctrl+C (Cmd+C on a Mac) to copy it, then paste it into your bug report."] = true,
	["Debug log is off."] = true,
	["Debug log is on for this session."] = true,
	["Debug log is on and pinned for this character."] = true,
	["Debug log is already on and pinned for this character."] = true,
	["Debug log is off for this session; it is still pinned."] = true,
	["Debug log is off and unpinned."] = true,
	["No addon has attached its log yet."] = true,
	["%s (last %d):"] = true,
	["%s: no lines yet."] = true,
	["Usage: /forever debug, /forever debug pin, /forever debug off, /forever debug show"] = true,

	-- Forever Core's shared family links.
	["Close"] = true,
	["Copy link"] = true,
	["Copy the address, then open it in your browser."] = true,
	["Don't suggest this again"] = true,
	["Forever addons"] = true,
	["Installed, turned off"] = true,
	["Not installed"] = true,
	["On"] = true,
	["Picks quests for your level and plans them into one journey."] = true,
	["Plans the cheapest route to your next profession rank."] = true,
	["Plans the quickest way anywhere and guides you there, with live boat and zeppelin times."] = true,
	["Quest automation, rare alerts and merchant handling for the default UI."] = true,
	["Show a quiet line where one of my other Forever addons would help. Only for addons you don't have."] = true,
	["Shows the Legacy challenges you can advance in each zone."] = true,
	["Suggest my other Forever addons"] = true,
	["The Forever addons are free, with nothing locked behind them. If they help, you can buy me a coffee."] = true,
	["This addon"] = true,
}

-- `true` marks a phrase that reads as its own English key.
for key, value in pairs(ns.L) do
	if value == true then
		ns.L[key] = key
	end
end

ns.ReportTitle = ns.L["Macro Assist Forever report"]
