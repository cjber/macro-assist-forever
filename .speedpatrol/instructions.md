# About the app

Macro Assist Forever is a World of Warcraft: Forever addon in Lua 5.1. The game cannot run here. The benchmarks run
the headless harness the specs use, which stubs the client API and loads the files the TOC lists in order.

- CI does not run Speedpatrol: this repo has no bench script, and the profile only times the spec gate, which is too
  noisy on a shared runner to fail a pull request on.
- Keep a change only when it speeds up a file the TOC loads or the gate itself. A change to a spec, a bench or other
  measuring code is not a speed-up.
- Every change must pass the full gate in `AGENTS.md` under "Commands", with lua-language-server 3.19.1 and stylua
  2.5.2 first on `PATH`, the versions CI uses.
- The vendored `tools/forever_tools/` and the files copied from forever-core are never edited by hand.
- Commit only the files the change needs: no profiler output or scratch files.
- Never use the network, and never start the game, Battle.net, Lutris or Wine. The headless client (forever-core's
  `wow-forever-addon/in-game.md`) tests the build linked into the game, not this checkout, so in-game checks belong to
  the agent that ships a change.
