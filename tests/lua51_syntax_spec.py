#!/usr/bin/env python3
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
spec = spec_from_file_location("check_lua51", ROOT / "tools/check_lua51.py")
checker = module_from_spec(spec)
assert spec.loader
spec.loader.exec_module(checker)

bad = ROOT / "tests" / "lua51_bad_snippet.lua"
good = ROOT / "tests" / "lua51_good_snippet.lua"
assert checker.check(bad), "the LuaJIT-only parenthesized method call was not rejected"
assert not checker.check(good), "the Lua 5.1-compatible local receiver was rejected"
print("lua51_syntax_spec: passed")
