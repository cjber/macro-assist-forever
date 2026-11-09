#!/usr/bin/env python3
"""Publish only a commit that passed this repository's complete CI workflow on main (forever_tools.release_check)."""

import sys

try:
    from tools.forever_tools import release_check
except ModuleNotFoundError:
    from forever_tools import release_check


if __name__ == "__main__":
    release_check.main()
    sys.exit(0)
