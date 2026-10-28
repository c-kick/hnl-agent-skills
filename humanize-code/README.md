# humanize-code

An agent skill that does for code what [`humanize`](../humanize/) does for text. It strips the patterns that give AI-written code away and reorganises the codebase, so a developer opening it for the first time can work out how it fits together.

The skill file is written for the agent (`SKILL.md`), but this file is intended for you as the user.

## What it removes

- Comments that narrate the code (`# Step 1: loop through the items`), changelog comments (`// Updated as requested`), hedging and commented-out code
- Error handling that swallows everything, and guards against cases that can't happen
- Factories with one product, interfaces with one implementation, options nobody sets
- `enhanced_`, `robust_`, `_v2`, `_new`, `handle_data()` naming
- Duplicated helpers, `utils` dumping grounds, god files, stray `IMPLEMENTATION_SUMMARY.md` files
- Emoji and chatty logging

The full list is in [`references/ai-code-tells.md`](references/ai-code-tells.md).

## What it adds

- A file layout that follows what each part of the system is responsible for
- Minimal comments in your language's standard doc format (docstrings, JSDoc, PHPDoc, godoc…): a one-to-three-line header per file, a one-line summary on public functions, and a short `why` comment where the code can't explain itself. No examples, no prose. Obvious code gets no comment at all. See [`references/comment-style.md`](references/comment-style.md).
- Optionally, a short `ARCHITECTURE.md` map

## Install

```bash
skill-add humanize-code code-simplification humanize
```

Or `skill-bundle-add code_development`, which includes all three. If you've installed `js-standards`, `php-documentation-standards` or `scss-standards`, the agent follows them for doc syntax and tags, but keeps the amount of commenting minimal. For example, it leaves out the `@example` blocks `php-documentation-standards` asks for. If you've installed `project-ambassador`, the agent asks it why unclear code exists before asking you.

## Use

Ask to "humanize this code", "de-AI this codebase" or "reorganise this so I can follow it", or run `/humanize-code`, optionally with a path.

```
0 preflight → 1 map → 2 plan (you approve) → 3 execute: structure, code, comments → 4 final pass → 5 report
```

**Preview first.** Ask to "show me what it would look like" or "put it next to the original", and the agent writes `<name>_humanized.<ext>` beside each file instead. Your originals and git history stay untouched and nothing is committed, so you can compare before deciding on a real run.

## What you need

- **A git repository with a clean working tree.** Every step is its own commit, so you can undo any of them.
- **Tests, ideally.** The agent runs them before starting and after every step. For files no test actually runs, an independent reviewer compares the old and new versions and lists every difference in behaviour, and the agent fixes or reverts each one. Without any tests, larger restructures are listed as recommendations rather than carried out.
- **Tests that check source text are respected.** If a test asserts that a file contains a certain string, the agent keeps that string exactly, even where it would have picked a better name.

## What happens to your project

- **Nothing changes before you approve the plan.** The plan lists every file move, every category of cleanup and every question the agent couldn't answer. You can strike items.
- **Behaviour stays identical.** If the agent finds a bug along the way, it reports it and leaves it alone.
- **File history survives moves.** Moves are committed separately from edits, so `git log --follow` keeps working.
- **Public names stay put.** Import paths and names that other code depends on are only changed if you approved exactly that.
- **Local commits only.** Nothing is pushed.

## Scanner

`scripts/scan-tells.sh [path]` is a quick heuristic scan you can also run yourself. It needs only bash, grep and perl. It over-reports on purpose: treat each hit as a place to look, not a verdict. Its structure section flags files that are hard to navigate even without obvious tells: everything in one scope, deep nesting, many inline callbacks, long lines, no file header.
