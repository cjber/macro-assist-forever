#!/usr/bin/env python3
"""Check the packed addon through forever_tools.package, including loaded files, credits and packaged specs."""

import sys
from pathlib import Path

try:
    from tools.forever_tools import package
except ModuleNotFoundError:
    from forever_tools import package

ROOT = Path(__file__).resolve().parent.parent
# Every spec but those that read the checkout rather than the addon: changelog_spec reads CHANGELOG.md, which
# .pkgmeta leaves out of the package.
REPO_ONLY = {"tests/changelog_spec.lua"}
POLICY = package.Policy(
    addons=("MacroAssistForever", "ForeverCore"),
    specs=tuple(
        spec
        for spec in sorted(path.relative_to(ROOT).as_posix() for path in ROOT.glob("tests/*_spec.lua"))
        if spec not in REPO_ONLY
    ),
)

if __name__ == "__main__":
    sys.exit(package.main(ROOT, POLICY))
