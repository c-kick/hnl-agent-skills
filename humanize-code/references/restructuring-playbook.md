# Restructuring Playbook

Restructure only when it makes the system easier to understand. Every move costs the reader who
already knew the old layout, and costs `git blame`. Each item in the plan has to justify that cost
in one line.

## When to restructure

| Signal | Move |
|---|---|
| A file holds several responsibilities that change for different reasons | Split by responsibility |
| Two or more files each hold half of one concept and import each other | Merge |
| `utils` / `helpers` / `common` with unrelated contents | Move each function to its callers' module or to a module named for its concept; delete the grab-bag once empty |
| Duplicated helpers across files | Keep one, in the module that owns the concept |
| Import cycles | Extract the shared piece into its own module, or merge the cycle |
| Layout disagrees with the architecture sketch from phase 1 | Move files so the tree matches the responsibilities |
| Version-suffixed files (`_v2`, `_new`) | Keep the live one under the plain name |
| Deeply nested package with one file per folder | Flatten |

## When not to

- The file is long but cohesive (one parser, one state machine, one table of data). Length alone is
  not a reason.
- The repo follows a framework's required layout (Django apps, Rails, Next.js routes, Home Assistant
  integrations, WordPress themes). Work inside it, not against it.
- The existing organisation is consistent, just not what you'd have picked. Taste is not a reason.
- The move would change a public import path, a module name in packaging config or an entrypoint
  others depend on, and the user hasn't approved exactly that in the plan.

## Organising principle

Follow the one the repo already uses (by feature or by layer). If it mixes both, pick the one most
of the code follows and list the outliers in the plan. For new modules, name them after the concept
they own (`billing`, `sync`, `parser`), never after their kind (`helpers`, `managers`, `misc`).

A good tree reads top-down: entrypoints and the main flow are easy to find, and each directory's
purpose is clear from its name.

## Mechanics

1. **Move first, edit second.** `git mv` in a commit of its own with no content changes, so git
   records a rename and history survives (`git log --follow`). Then a separate commit for the
   import fixes and any content edits.
2. **Splitting a file.** `git mv` the original to the new name that keeps most of its content, then
   carve the other parts out into new files. Git follows the bulk of the history.
3. **Update every reference.** Imports, but also packaging config (`pyproject.toml`,
   `package.json` `exports`/`main`/`bin`, `composer.json` autoload), Dockerfiles, CI config, scripts,
   docs, string-based lookups and dynamic imports. Grep for the old module name and path afterwards;
   it should appear nowhere except in git history.
4. **No re-export shims** at the old location, unless the old path is public and the user chose a
   deprecation path in the plan.
5. **Tests after each step.** A pure move that breaks tests only through import paths may update
   those imports. Anything else breaking means revert.

## Without tests

Without tests, only make changes you can prove are behaviour-neutral by other means:

- Pure moves and renames with every reference updated, verified by the language's own checks:
  import/compile (`python -m compileall`, `tsc --noEmit`, `php -l`, `go build`, `cargo check`), a
  linter, and a smoke run of the entrypoint if it's safe to run.
- Comment and docstring changes.
- Removing clearly dead code (no references, including dynamic ones).

Tier B changes inside a file (extracting functions, merging duplicated blocks, naming conditions)
are allowed without tests only when the independent comparison in `SKILL.md` phase 3d comes back
clean. Keep side effects in their original order. Everything else in tier B goes into the report
as a recommendation, or waits until the user has agreed to add tests first.

## Source-pinned tests

Some suites assert on source text instead of behaviour (`"renderSourceCheck(result)" in source`).
They make certain names and literals part of the contract. Keep every pinned string exactly, even
when a better name exists. If a pinned string blocks a change you consider important, list it in the
report as a recommendation to rewrite that test as a behaviour test. Don't change it yourself.

## ARCHITECTURE.md

Add one only if the user approved it in the plan and the system has more than a handful of parts.
Contents: the parts and their responsibility (one line each), the main flow in a few sentences or a
small diagram, and where to start reading. No history, no feature list, no future plans. Run it
through `humanize`.
