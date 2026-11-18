### Fixed

- **Searching the icon picker does less work on each letter.** The search lowered every icon name and the typed text again for each of the client's 30,000 icons on every keystroke. It now lowers the typed text once and keeps each icon's lowercase name with the icon after the first search, and the same icons are found in the same order.
- **The macro list reuses each macro's summary.** Refreshing the list (a macro changed, spells changed, a tab switch) parsed every macro body again to rebuild its one-line summary. A summary depends only on its body, so the list now parses only a macro whose text changed.
