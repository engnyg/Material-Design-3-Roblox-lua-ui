#!/usr/bin/env python3
"""Run the bundle smoke test under the standalone `luau` CLI.

The Luau CLI has no file I/O, so this stitches the Roblox mock, the bundle
source (as a long-string literal) and test.luau into one script and runs it.

Usage: python3 tools/bundle.py && python3 tools/smoke/run.py
       (set LUAU=/path/to/luau if it isn't on PATH)
"""
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent

bundle = (ROOT / "dist" / "MaterialDesign3.luau").read_text(encoding="utf-8")
mock = (HERE / "roblox_mock.luau").read_text(encoding="utf-8")
test = (HERE / "test.luau").read_text(encoding="utf-8")

level = 1
while f"]{'=' * level}]" in bundle:
    level += 1
eq = "=" * level

script = (
    f"local mock = (function()\n{mock}\nend)()\n"
    f"local BUNDLE_SOURCE = [{eq}[\n{bundle}]{eq}]\n"
    f"{test}\n"
)

with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as f:
    f.write(script)
    path = f.name

try:
    result = subprocess.run([os.environ.get("LUAU", "luau"), path])
finally:
    os.unlink(path)
sys.exit(result.returncode)
