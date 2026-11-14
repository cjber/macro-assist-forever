"""Editor previews stay inside the runtime editor's measured visual rows."""

import re
import unittest

import screenshots


class Canvas:
    def __init__(self):
        self.texts = []
        self.fills = []

    @staticmethod
    def text_width(text, _font):
        plain = re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", text).replace("||", "|")
        return len(plain) * 8

    def fill(self, *args):
        self.fills.append(args)

    def text(self, x, y, text, font, *_args, **_kwargs):
        self.texts.append((x, y, text, self.text_width(text, font)))


class EditorPreviewTest(unittest.TestCase):
    def test_long_assignment_wraps_inside_editor_and_caret_follows(self):
        canvas = Canvas()
        body = screenshots.ROSTER_BODY + " with a very long assignment for the next player"
        text_x, text_y, text_width, caret_position = screenshots.draw_editor(
            canvas, body, 1, len(body.split("\n")[1]), {"lines": {}, "diagnostics": []}
        )
        x, _, width, _ = screenshots.editor_geometry()
        text_x = x + screenshots.GUTTER_WIDTH + 10
        rows = [entry for entry in canvas.texts if entry[0] == text_x]
        self.assertGreater(len(rows), 2)
        for left, _, text, extent in rows:
            with self.subTest(text=text):
                self.assertLessEqual(left + extent, x + width - 8)
        caret = canvas.fills[-1]
        self.assertEqual(caret[1], rows[-1][1])
        self.assertLessEqual(caret[0], x + width - 8)
        fill_count = len(canvas.fills)
        screenshots.draw_completion(canvas, ([], 0, [], 0, 0), caret_position, text_x, text_y, text_width)
        popup = canvas.fills[fill_count]
        self.assertEqual(popup[1], caret[1] + screenshots.LINE_HEIGHT + 2)


if __name__ == "__main__":
    unittest.main()
