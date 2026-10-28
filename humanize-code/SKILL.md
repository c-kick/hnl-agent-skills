---
name: humanize-code
description: >
  Removes the tell-tale patterns of AI-generated code from a codebase and reorganises it so a human
  developer can understand how it works: narrating comments, defensive noise, speculative
  abstractions, duplicated helpers, "enhanced_"/"_v2" naming, emoji logging, god files and utils
  dumping grounds. Restructures files and modules when that helps comprehension, and reduces
  comments to terse, language-standard annotations of the essentials. Use when the user asks to
  "humanize this code", "de-AI this codebase", "clean up AI slop in the code", "make this look like
  a human wrote it", "make this codebase legible", "reorganise this so I can follow it", or invokes
  /humanize-code. Always proposes a plan and waits for approval before changing anything. Behaviour
  is preserved exactly. Not for fixing bugs (use bug-hunter or systematic-debugging) or for small
  local cleanups of a recent change (use code-simplification directly).
user-invocable: true
---

# Humanize Code

`humanize` removes the signs of AI writing from prose. This skill does the same for code. The
goal is a codebase that a competent developer can open cold and understand: where things live,
what each part is responsible for, and why the non-obvious parts are the way they are.

Three things define success:

1. **Structure explains the system.** File and module boundaries follow responsibilities. The
   file tree is a usable map.
2. **Code carries no AI residue.** No narration, no defensive theatre, no one-use abstractions, no
   duplicated helpers, no hype vocabulary. See `references/ai-code-tells.md`.
3. **Comments are minimal and standard.** The language's own doc format, the essentials only. See
   `references/comment-style.md`.

Behaviour never changes. Every input, output, side effect, error and public API stays identical.
If a change can't be shown to preserve behaviour, it isn't made.

The measure is how quickly a reader understands the code, not line count. Naming the pieces often
makes a file longer; that's fine.

## Requires

This skill composes other skills from this repository. Install them alongside it:

```bash
skill-add humanize-code code-simplification humanize
```

| Skill | Role | Needed |
|---|---|---|
| `code-simplification` | Line-level cleanup inside functions (phase 3b) | Yes |
| `humanize` | Prose: README, `ARCHITECTURE.md`, wording of docstrings and messages | Yes |
| `js-standards`, `php-documentation-standards`, `scss-standards` | Language conventions and doc-tag rules, when the repo uses that language | If installed |
| `project-ambassador` | Answers "why does this exist / is this intended" questions before they reach the user | If installed |

Load each at the phase that uses it and follow its method. If a required one is missing, say so in
the report and apply its principles inline.

**Precedence for comments.** A language skill decides *format*: which doc syntax, which tags, type
hints. This skill decides *amount*: when a language skill asks for `@example` blocks, bullet-list
prose or descriptions that restate the signature, leave them out. Where the repo's own CLAUDE.md
or AGENTS.md sets a documentation rule, that rule beats both.

## Working files

Keep the working documents in a `humanize-code/` folder in the session scratchpad (or
`/tmp/humanize-code-<project>/` if there is none), never in the repository:

- `01-map.md`: architecture sketch and verified tell inventory
- `02-plan.md`: the approved plan, with a checkbox per step
- `03-progress.md`: what's done, commit hashes, test results

If the context was compacted, read these and `git log`/`git diff` before continuing. Trust the code
over the files when they disagree.

## Phase 0: Preflight

1. Read CLAUDE.md / AGENTS.md and any contributing guide. Note commit conventions, doc rules and
   anything off-limits.
2. **Git.** The tree must be a git repository with a clean working tree. If it's dirty, ask the user
   to commit or stash first. If it isn't a repo, offer `git init` plus an initial commit.
3. **Tests.** Find and run the test suite and record the baseline. If tests fail before you start,
   stop and report. If there are none, say so. In that case the plan must stay low-risk (see
   `references/restructuring-playbook.md`, "Without tests").
4. **Scope.** Default to the whole repository, excluding vendored, generated and build output. If
   the user named a path, use that.
5. **Mode.** Default is **in place**: the full plan, approval and commit flow below. If the user asks
   to see a result first ("show me what it would look like", "put it next to the original"), use
   **preview** mode: for each file in scope, write `<name>_humanized.<ext>` next to the original,
   leave the original and git history untouched, and don't commit. Structural moves across files
   are listed in the report instead of carried out. The user asking for the result directly counts
   as approval of the plan for a preview. Summarise the plan in the report instead.
6. **Public surface.** Work out whether this code is consumed by others (a published package, a
   library imported by other repos, an HTTP API, a CLI, config keys). Exported names and
   entrypoints that others depend on stay as they are.
7. **Source-pinned tests.** Search the tests for ones that read source files as text (Python
   `read_text()` / `open()` on a source path, Node `readFileSync` of a `.js`/`.mjs`/`.ts`, PHP
   `file_get_contents` of a `.php`) and assert on its contents. List every string they pin per
   file. Those strings are fixed, like public API: keep them byte for byte, including function
   names and literal lists. Mention in the report which names you'd have changed without them.
8. **Behaviour coverage.** For each file in scope, note whether any test actually *executes* it
   (not just reads it as text). Files without one need the independent comparison in phase 3.

## Phase 1: Map

Understand the codebase before judging it.

1. Read the entrypoints, then follow the main flows. Write a short architecture sketch in
   `01-map.md`: the major parts, what each one does, how data moves between them, and where the file
   layout disagrees with those responsibilities.
2. Run `scripts/scan-tells.sh <path>` for a heuristic first pass. It over-reports. Every hit is
   a lead to verify by reading the code, not a finding. Its structure section (anonymous closures
   versus named functions, nesting depth, long lines) often says more than the tell counts:
   hardened code can be free of comment slop and still be unreadable.
3. Walk the categories in `references/ai-code-tells.md` by hand as well. The structural tells
   (duplicated helpers, one-implementation interfaces, dead config) don't show up in a grep.
4. For any code whose purpose is unclear, apply Chesterton's fence: check `git log -L` / blame and
   callers. Ask `project-ambassador` if installed. What's left unresolved goes into the plan as a
   question, never as a deletion.

## Phase 2: Plan (always approved by the user)

Write `02-plan.md` in three tiers, in the order they'll run:

- **A. Structure.** File moves, splits, merges, renames and new module boundaries. One line each:
  what moves where, and why it helps a reader.
- **B. Code tells.** Grouped by category, with file references and counts. Mark which go through
  `code-simplification` and which are structural (for example, merging duplicated helpers).
- **C. Comments and docs.** Removals (narration, changelog comments, commented-out code), module
  headers to add, public API docs to add or trim, and any README / `ARCHITECTURE.md` work.

End with open questions (code whose purpose you couldn't establish) and a risk note (what the tests
don't cover).

**Present the plan to the user and stop. No code changes before explicit approval,** whatever the
size of the plan. The user may strike items. Record their decisions in `02-plan.md`. The only
exception is preview mode (phase 0), where the user already asked for the result.

## Phase 3: Execute

Work tier by tier. Run the tests after every step and commit per step, following the repo's commit
conventions. A failing test means revert that step and re-think it, never edit the test to fit
(unless the step was a pure file move and the test only needs its import path updated).

**3a. Structure.** Follow `references/restructuring-playbook.md`. Commit moves (`git mv`) separately
from content edits so git keeps file history. Then fix imports, then run the tests.

**3b. Code tells.** Load `code-simplification` and apply its process to each item in tier B.
Structural tells, such as collapsing a one-product factory or merging duplicate helpers across
files, are done here too, still one change per commit.

**3c. Comments.** Apply `references/comment-style.md` together with the relevant language skill.
Do this last, when the structure is final, so no comment describes a layout that no longer exists.

**3d. Files no test executes.** Tests passing proves nothing for a file that only source-pinned
tests (or none) touch. For each such file, hand the old and new versions to an independent
reviewer: a subagent if your harness has one (e.g. a code-reviewer agent), otherwise a separate
pass of your own that reads only the two versions. Ask it to list every observable difference:
requests (URL, method, body), DOM or state mutations and their order, busy/disabled state at each
`await`, error paths, what throws when an element or value is missing (watch optional chaining),
timers, storage, listener targets, module-load order and TDZ. Fix or revert every difference it
finds, and name the check in the report.

Record progress in `03-progress.md` as you go.

## Phase 4: Final pass

1. Read the full diff (`git diff <baseline>..HEAD`) and the resulting tree, and ask yourself:
   *"What still makes this code look AI-generated?"* Answer briefly, then fix what's found (same
   rules: tests, one commit per step).
2. Pick three files a newcomer would open first. Check that each file's purpose is clear from its
   name and header alone.
3. Prose: run `humanize` over any README or doc text you wrote or changed. If the plan included an
   `ARCHITECTURE.md`, it's a short map (parts, responsibilities, main flow), not an essay.

## Phase 5: Report

Report to the user, in this order:

- Tests: baseline versus final (they must match or improve). In preview mode, run them with the
  preview copied over the original in a throwaway worktree, then remove the worktree.
- How each file's behaviour was verified: executed by tests, or the independent comparison (3d)
  and what it found.
- What changed, per tier, with commit hashes, and the new file tree if the structure changed.
- Anything a consumer of the code must know (should be nothing; if an import path of a public module
  changed, the user approved it in the plan, so say so).
- Items skipped and why, plus open questions still outstanding.

Nothing is pushed.

## Red flags

- Adding comments to "document" code instead of making the code clearer.
- Deleting code whose purpose you couldn't establish.
- A restructure that makes the tree deeper without making it clearer.
- Renaming things to match your taste instead of the repo's conventions.
- Removing error handling that guards a real failure (only *swallowing* or *impossible-case*
  handling is a tell).
- Editing a test so it passes.
- Mixing a behaviour change into the cleanup. If you find a bug, note it in the report and leave it
  alone.
- Reordering side effects while merging code into a helper. Two DOM writes, state updates or calls
  that look independent can depend on each other (a later `querySelector('span')` finding a node
  the earlier step inserted). Keep the original order unless you've proven it doesn't matter.
- Renaming or restructuring a string that a source-pinned test asserts on.
- Trimming lines for the sake of a shorter file.

## Reference

- `references/ai-code-tells.md`: the tell catalog with what to do about each.
- `references/comment-style.md`: comment amount and per-language standard formats.
- `references/restructuring-playbook.md`: when and how to split, merge and move.
- `scripts/scan-tells.sh`: heuristic scanner (bash, grep, perl; no install needed).
