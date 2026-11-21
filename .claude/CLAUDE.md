# sabotage.ai: rules for AI agents

A 2D side-scrolling anti-AI platformer in Godot 4.7 (GDScript), for Android, web and desktop. Read the rule files below before changing anything; they are short.

| File | What it covers |
|------|----------------|
| [rules/code.md](rules/code.md) | how code is written: object-oriented, reusable, no magic values, comments |
| [rules/structure.md](rules/structure.md) | where files go: folders by type, what belongs in `common/` |
| [rules/testing.md](rules/testing.md) | tests, the `tmp/` scratch folder, flakiness, how to run everything |
| [rules/assets.md](rules/assets.md) | pictures and sounds: generators, no dead assets, effects |
| [rules/levels.md](rules/levels.md) | levels, the level editor, keeping the editor up to date |

Work habits:
- Use `tmp/` (git-ignored) for every scratch script, screenshot and log. Never leave temporary files anywhere else.
- Do not commit or push unless asked. Never commit something nothing uses.
- Never add Claude (or any AI) as a co-author: no `Co-Authored-By` trailer and no "Generated with" line in commit messages or pull request descriptions.
- Run `tools/run_tests.sh` before you say something is done; a change is done when every test passes, every time.
- Project docs live in [docs/](../docs/); keep them in step with the code you change.
