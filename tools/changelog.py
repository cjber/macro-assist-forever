#!/usr/bin/env python3
"""Print one version's CHANGELOG.md section, or check that every release has one (forever_tools.changelog).

python3 tools/changelog.py 0.1.0           # that version's entry (a leading v is fine)
python3 tools/changelog.py --check         # every tag has an entry, and Unreleased is there
python3 tools/changelog.py --check 0.2.0   # that version has an entry, before it is tagged
"""

from pathlib import Path

try:
    from tools.forever_tools import changelog
except ModuleNotFoundError:
    from forever_tools import changelog


if __name__ == "__main__":
    changelog.main(Path(__file__).resolve().parent.parent)
