### Fixed

- **Searching the icon picker no longer stalls on each letter.** The search lowered every icon name and the typed text again for each of the client's 30,000 icons on every keystroke, taking about 5 ms a letter in the headless harness. It now lowers the typed text once and keeps each icon's lowercase name with the icon, so a letter costs under 1 ms for most searches and the same icons are found in the same order.
