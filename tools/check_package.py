#!/usr/bin/env python3
"""Check the packed addon through forever_tools.package, including loaded files, credits and packaged specs."""

import sys
from pathlib import Path

try:
    from tools.forever_tools import package
except ModuleNotFoundError:
    from forever_tools import package

ROOT = Path(__file__).resolve().parent.parent
POLICY = package.Policy(
    addons=("MacroAssistForever", "ForeverCore"),
    specs=tuple(sorted(path.relative_to(ROOT).as_posix() for path in ROOT.glob("tests/*_spec.lua"))),
)

if __name__ == "__main__":
    sys.exit(package.main(ROOT, POLICY))
