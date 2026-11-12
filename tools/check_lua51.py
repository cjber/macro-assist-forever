#!/usr/bin/env python3
"""Reject Lua syntax accepted by LuaJIT but rejected by the WoW Lua 5.1 parser."""

import re
import sys
from pathlib import Path


# Lua 5.1 does not allow a parenthesized expression as the receiver of a method
# call. LuaJIT accepts it, which let the packaged addon reach the client before
# failing to parse. Keep this check narrow and run it over TOC-loaded sources.
PAREN_METHOD = re.compile(r"\([^\n]*--\[\[@as [^]]+\]\]\s*\):")


def check(path: Path) -> list[str]:
    findings = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if PAREN_METHOD.search(line) and not line.lstrip().startswith("--"):
            findings.append(f"{path}:{number}: parenthesized method receiver")
    return findings


def toc_files(root: Path) -> list[Path]:
    toc = next(root.glob("*.toc"))
    files = []
    for line in toc.read_text(encoding="utf-8-sig").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and line.lower().endswith(".lua"):
            files.append(root / line.replace("\\", "/"))
    return files


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1]
    paths = [Path(arg) for arg in sys.argv[1:]] or toc_files(root)
    errors = [error for path in paths for error in check(path)]
    if errors:
        print("\n".join(errors))
        raise SystemExit(1)
    print(f"Lua 5.1 compatibility: checked {len(paths)} files")
