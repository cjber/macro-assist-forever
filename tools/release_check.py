"""Publish only a commit that passed this repository's complete CI workflow on main (forever_tools.release_check)."""

try:
    from tools.forever_tools.release_check import main, verified
except ModuleNotFoundError:
    from forever_tools.release_check import main, verified

__all__ = ["main", "verified"]

if __name__ == "__main__":
    main()
