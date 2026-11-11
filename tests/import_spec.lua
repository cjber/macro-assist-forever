-- What the Import box makes of pasted text: a macro, a MySlot export, prose, or nothing.
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, ("%s: expected %q, got %q"):format(label, tostring(expected), tostring(actual)))
end

local ns = {}
local chunk = assert(loadfile("Core/Import.lua"))
chunk("MacroAssistForever", ns)

local function kind(text)
	return ns.Import.Classify(text).kind
end

equal(kind("/cast Arcane Shot"), "macro", "a command line is a macro")
equal(kind("#showtooltip\n/cast Arcane Shot"), "macro", "a directive is a macro")
equal(kind("  /cast Arcane Shot"), "macro", "leading whitespace before a command still counts")
equal(kind("A note\n/yell Hello"), "macro", "a macro may start with a comment line")
equal(kind("/say hello"), "macro", "a chat command is a macro")
equal(kind("I like pets\nand healing"), "text", "prose without a command is not a macro")
equal(kind(""), "empty", "an empty box holds nothing")
equal(kind("  \n\t\n"), "empty", "whitespace alone holds nothing")
equal(kind(nil), "empty", "a missing value holds nothing")
equal(kind("!MySlot:AAAABBBBCCCC"), "myslot", "a MySlot export is named, not saved")
equal(kind("  !myslot:AAAABBBB"), "myslot", "a leading space does not hide a MySlot export")
equal(kind("a note\n!MySlot:AAAA"), "myslot", "a MySlot export after a comment is still recognised")

-- The body keeps the pasted text, with only the line ending the macro store cannot use changed.
local plain = ns.Import.Classify("/cast Arcane Shot\n/startattack")
equal(plain.body, "/cast Arcane Shot\n/startattack", "the macro body is kept")
equal(plain.kind, "macro", "the body and the kind agree")
local windows = ns.Import.Classify("/cast Arcane Shot\r\n/startattack\r\n")
equal(windows.body, "/cast Arcane Shot\n/startattack\n", "Windows line endings become newlines")
equal(windows.kind, "macro", "Windows line endings still make a macro")

print(("%d checks passed"):format(checks))
