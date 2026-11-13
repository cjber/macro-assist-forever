-- The editor's measured rows and click rule: wrap points, x offsets, and a click right of a line's end.
local checks = 0
local function equal(actual, expected, label)
	checks = checks + 1
	assert(actual == expected, ("%s: expected %q, got %q"):format(label, tostring(expected), tostring(actual)))
end

local ns = {}
local function load(path)
	local chunk = assert(loadfile(path))
	chunk("MacroAssistForever", ns)
end
load("Locales/enUS.lua")
load("Core/Lexer.lua")
load("Core/Parser.lua")
load("UI/Editor.lua")

-- A FontString with the bundled mono font's fixed advance. Its measured width is one advance per byte; the row
-- code only needs this single-line width, exactly what the editor's probe supplies in the client.
local function FontString(advance)
	local font = { text = "" }
	function font:SetText(text)
		self.text = text or ""
	end
	function font:GetStringWidth()
		return #self.text * advance
	end
	return font
end

local function measure(font)
	return {
		width = function(text)
			font:SetText(text)
			return font:GetStringWidth()
		end,
	}
end

local ADVANCE = 10
local LINE_HEIGHT = 19
local font = FontString(ADVANCE)
local widths = measure(font)

-- At 70 units a row holds seven characters, so "aa bb cc dd" breaks after the space following "bb" and keeps that
-- space at the end of the first row. The next row starts at "cc", not at the space or in the middle of a word.
local rows = ns.Editor.LayoutRows("aa bb cc dd", 70, LINE_HEIGHT, widths)
equal(#rows, 2, "the long line wraps onto two rows")
equal(rows[1].line, 1, "the first row is on line 1")
equal(rows[1].row, 0, "the first row is row 0 of its line")
equal(rows[1].from, 1, "the first row starts at the first byte")
equal(rows[1].to, 7, "the first row ends after the wrapped space")
equal(rows[1].text, "aa bb ", "the first row keeps the space it wrapped at")
equal(rows[1].y, 0, "the first row is at the top")
equal(rows[2].from, 7, "the second row starts with the next word")
equal(rows[2].to, 12, "the second row ends at the end of the text")
equal(rows[2].text, "cc dd", "the second row holds the rest")
equal(rows[2].y, LINE_HEIGHT, "the second row sits one measured line lower")

-- x offsets are measured from the row start, never from an average column on the logical line.
equal(ns.Editor.RowOffset(rows[1], 3, widths), 30, "three characters into the first row")
equal(ns.Editor.RowOffset(rows[1], 6, widths), 60, "the first row's measured width")
equal(ns.Editor.RowOffset(rows[2], 5, widths), 0, "the second row begins at x 0")
equal(ns.Editor.RowOffset(rows[2], 11, widths), 50, "the second row's last position")

-- Cursor positions at a wrap belong to the following row; a line's end stays on that line, before its newline.
equal(ns.Editor.RowAtCursor(rows, 5), 1, "a position inside the first row stays there")
equal(ns.Editor.RowAtCursor(rows, 6), 2, "a wrapped position belongs to the next row")
equal(ns.Editor.RowAtCursor(rows, 11), 2, "the end of the text stays on the last row")

-- A word wider than the whole row breaks at the longest measured prefix, so it still makes progress.
local long = ns.Editor.LayoutRows("superlongword", 70, LINE_HEIGHT, widths)
equal(#long, 2, "a word wider than the row breaks in two")
equal(long[1].text, "superlo", "the first piece is the longest that fits")
equal(long[2].text, "ngword", "the second piece keeps the rest")

-- A hanging indent narrows every row a wrap created, never the logical line's first row, so a run that fit the full
-- width can wrap again and only a real newline starts at the left edge.
local fullRows = ns.Editor.LayoutRows("aaaa bbbb cccccc", 100, LINE_HEIGHT, widths)
equal(#fullRows, 2, "the run fits two full-width rows")
local hangingRows = ns.Editor.LayoutRows("aaaa bbbb cccccc", 100, LINE_HEIGHT, widths, 50)
equal(#hangingRows, 3, "the hanging indent narrows the wrapped row")
equal(hangingRows[1].text, "aaaa bbbb ", "the first row keeps the whole width")
equal(hangingRows[2].text, "ccccc", "the narrowed row takes the longest prefix")
equal(hangingRows[3].text, "c", "the rest moves to a further row")

-- The click rule: rows on three logical lines, wide enough that nothing wraps.
local lines = ns.Editor.LayoutRows("one two\nthree four\nfive", 1000, LINE_HEIGHT, widths)
equal(#lines, 3, "the three logical lines are three rows")
equal(lines[2].from, 9, "line 2 starts after the first newline")
equal(lines[2].to, 19, "line 2 ends before its newline")
equal(ns.Editor.RowAtCursor(lines, 7), 1, "the cursor before a newline stays on that line")
equal(ns.Editor.RowAtCursor(lines, 8), 2, "the cursor after a newline moves to the next line")

-- A click right of line 2's last character: the EditBox reports the start of line 3, but the cursor must stay at
-- the end of line 2, before its newline.
equal(
	ns.Editor.ClickCursor(lines, 2, 2, 3, 1000, widths),
	18,
	"a click right of line 2's end leaves the cursor at line 2's end"
)
-- A click on the row the EditBox already reports changes nothing.
equal(ns.Editor.ClickCursor(lines, 2, 2, 2, 1000, widths), nil, "a click on the current row is left alone")
-- A drag that leaves the row it started on is left alone too.
equal(ns.Editor.ClickCursor(lines, 2, 3, 3, 1000, widths), nil, "a release on another row is left alone")
-- A row outside the text has no character to land on.
equal(ns.Editor.ClickCursor(lines, 4, 4, 3, 1000, widths), nil, "a row past the text is left alone")
-- Inside a row, the nearest character boundary wins.
equal(ns.Editor.ClickCursor(lines, 2, 2, 3, 25, widths), 10, "the nearest character on line 2")

-- The release and cursor-update halves of the click rule, driven without the client. The mouse-up handler reads the
-- row from the EditBox's live position, never from the cached cursorRow, and the cursor update gets one chance.
local function fakeEditor(cursor)
	local edit = { position = cursor }
	function edit:GetCursorPosition()
		return self.position
	end
	function edit:SetCursorPosition(position)
		self.position = position
	end
	local editor = setmetatable({ rows = lines, edit = edit, textMeasure = widths }, { __index = ns.Editor })
	return editor, edit
end

-- What OnMouseUp does once it has the pointer row and the edit's left edge.
local function mouseUp(editor, edit, upRow, x)
	local position = edit:GetCursorPosition()
	editor:ReleaseClick(upRow, x, position and ns.Editor.RowAtCursor(editor.rows, position))
end

-- The client put the cursor at the start of line 3 before the release, but the last OnCursorChanged still cached line
-- 2. The live position must win, so the cursor lands at the end of line 2, not at the click record's own row.
local editor, edit = fakeEditor(19)
editor.cursorRow = 2
editor.click = { row = 2 }
mouseUp(editor, edit, 2, 1000)
equal(edit.position, 18, "a click right of line 2's end lands at the end of line 2")
equal(editor.click, nil, "a resolved click is dropped at the release")

-- The client has not moved its cursor yet at the release, so the live position is still line 2 and the rule cannot
-- resolve the click. The record waits for exactly one cursor update, on the row that update reports.
editor, edit = fakeEditor(10)
editor.cursorRow = 2
editor.click = { row = 2 }
mouseUp(editor, edit, 2, 1000)
equal(edit.position, 10, "an unresolved release leaves the cursor alone")
equal(editor.click and editor.click.pending, true, "an unresolved click waits for the client's cursor")
editor.cursorRow = 3
editor:ResolvePendingClick(editor.cursorRow)
equal(edit.position, 18, "the waiting click lands at the end of line 2 on the cursor update")
equal(editor.click, nil, "the waiting click is dropped after one cursor update")
edit.position = 23
editor:ResolvePendingClick(3)
equal(edit.position, 23, "a dropped click does not move a later cursor update")

-- The client reports its cursor before the release. The record has no release yet, so the update changes nothing and
-- the release then resolves against the live row.
editor, edit = fakeEditor(19)
editor.click = { row = 2 }
editor.cursorRow = 3
editor:ResolvePendingClick(editor.cursorRow)
equal(edit.position, 19, "a cursor update before the release leaves the cursor alone")
equal(editor.click and editor.click.row, 2, "the click record survives until its release")
mouseUp(editor, edit, 2, 1000)
equal(edit.position, 18, "the release after the cursor update still lands at the end of line 2")
equal(editor.click, nil, "the click record is dropped once resolved")

print(("editor layout: %d checks"):format(checks))
