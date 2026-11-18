#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# --no-luals runs every check here but LuaLS itself, which holds gigabytes; CI always runs it.
run_luals=1
if [[ ${1:-} == --no-luals ]]; then
    run_luals=0
fi
annotations=.types/vscode-wow-api
# The annotation checkout and the LuaLS version come from tools/toolchain.json, synced from ForeverCore: the one
# place either is pinned, and the file CI installs LuaLS from.
pins=$(python3 -c 'import json; t = json.load(open("tools/toolchain.json"))["tools"]; print(t["annotations"]["commit"], t["luals"]["version"])')
revision=${pins% *}
luals=${pins#* }
if [[ ! -d "$annotations/.git" ]]; then
    mkdir -p "$annotations"
    git -C "$annotations" init --quiet
    git -C "$annotations" remote add origin https://github.com/Ketho/vscode-wow-api.git
    git -C "$annotations" fetch --depth=1 origin "$revision"
    git -C "$annotations" checkout --quiet --detach FETCH_HEAD
    # The pinned commit also pins FrameXML's submodule; never follow its branch tip.
    git -C "$annotations" submodule update --init --depth 1 Annotations/FrameXML
fi
if [[ "$(git -C "$annotations" rev-parse HEAD)" != "$revision" ]] ||
    [[ -n "$(git -C "$annotations" status --porcelain)" ]] ||
    [[ "$(git -C "$annotations" submodule status Annotations/FrameXML)" != ' '* ]]; then
    echo "Expected a clean WoW API checkout at $revision, with its pinned FrameXML submodule, in $annotations" >&2
    exit 1
fi
if (( run_luals )) && [[ "$(lua-language-server --version)" != "$luals" ]]; then
    echo "Install lua-language-server $luals to match CI." >&2
    exit 1
fi

python3 tools/forever_tools/sync.py check
python3 tools/check_family.py
python3 tools/check_store_page.py
python3 tools/typecheck_coverage.py
python3 tools/check_client_load.py
python3 tools/check_menu_scroll.py
python3 tools/lint_client_calls.py
python3 tools/check_font_glyphs.py
# --no-luals (gate --changed): the checks above run, and the whole-repo LuaLS run is left to CI.
if (( ! run_luals )); then
    echo "typecheck: LuaLS left to CI (--no-luals)"
    exit 0
fi
# A fresh output path prevents a crashed server from reusing an earlier clean report.
report_dir=$(mktemp -d)
trap 'rm -rf "$report_dir"' EXIT
status=0
lua-language-server --check . --checklevel=Information --check_format=json \
    --check_out_path="$report_dir/check.json" --logpath="$report_dir" > "$report_dir/output.txt" 2>&1 || status=$?
python3 - "$report_dir" "$status" <<'PY'
import json
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

report_dir = Path(sys.argv[1])
report = report_dir / "check.json"
if not report.is_file():
    sys.exit("LuaLS did not produce a report:\n" + (report_dir / "output.txt").read_text())
results = json.loads(report.read_text()) or {}
count = 0
for uri, diagnostics in sorted(results.items()):
    path = Path(unquote(urlparse(uri).path)).relative_to(Path.cwd())
    for diagnostic in sorted(diagnostics, key=lambda d: d["range"]["start"]["line"]):
        line = diagnostic["range"]["start"]["line"] + 1
        message = diagnostic["message"].replace("\n", " ")
        print(f"{path}:{line}: {diagnostic['code']}: {message}")
        count += 1
if count or int(sys.argv[2]):
    if not count:
        print((report_dir / "output.txt").read_text())
    sys.exit(f"LuaLS: {count} diagnostics (exit {sys.argv[2]})")
print("LuaLS: no diagnostics")
PY
