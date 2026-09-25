---
name: review-and-harden
description: >
  End-to-end hardening pipeline for a codebase: hostile review, then project-ambassador verdicts,
  then a staff-review implementation plan, then implementing every accepted fix (each proven by a
  test), then one bug-hunter sweep, then a final fix round, then a report and a ping to the user.
  Use this whenever the user asks to chain these reviews ("run a hostile review, ask the ambassador,
  have staff-review plan it, implement everything, then bug-hunt"), asks for a "full hardening pass",
  "review and fix everything", "make this production-ready before I turn it on", "the review pipeline",
  or wants an unattended review-then-fix cycle they can walk away from. Prefer this over invoking
  hostile-review, staff-review or bug-hunter on their own when the user wants the findings *fixed*,
  not just reported.
---

# Review and Harden

A chained, mostly unattended pipeline that takes a working codebase to a hardened, committed,
deployed state. Each stage writes a handoff file that the next stage reads, so the chain survives
context compaction and the user can audit every decision afterwards.

```
0 preflight → 1 hostile review → 2 ambassador verdicts → 3 staff plan
   → 4 implement (phased, test per fix) → 5 bug hunt (prove, don't fix) → 6 final fixes → 7 report + ping
```

The user usually starts this and walks away. Run to completion without check-ins unless a decision
is truly theirs (see "When to stop and ask"), and make the final report self-contained.

## Cost check

This is an expensive skill. It runs four other skills in sequence, re-reads the codebase in
several stages, runs the full test suite many times and implements every accepted fix, so it
uses far more tokens and time than any stage skill on its own.

- **The user asked for the pipeline explicitly** (named this skill, a "full hardening pass", or the
  chain of stages): proceed without asking.
- **It triggered from a looser request** ("review this", "find what's wrong"): before stage 0, ask
  once. Say in one line that this runs the full review-fix-bug-hunt pipeline and is expensive,
  and offer the cheaper option of just `hostile-review` or `bug-hunter`, which report without fixing.

Ask this before the user walks away, never mid-run. Preflight (below) can raise two more questions,
about git and about how fixes will be proven. Settle those first, then ask everything in one message.

## Requires

This pipeline orchestrates four other skills from this repository. Install them alongside it:

```bash
skill-add review-and-harden hostile-review project-ambassador staff-review bug-hunter
```

(`skill-bundle-add code_development` installs all five.) Load each one at its stage and follow its
method and output format; this file only adds the glue, the handoff contract and the lessons learned.

| Stage | Skill | Handoff file |
|---|---|---|
| 1 | `hostile-review` | `01-hostile-review.md` |
| 2 | `project-ambassador` | `02-ambassador-verdicts.md` |
| 3 | `staff-review` (as a planner) | `03-staff-plan.md` |
| 4, 6 | (none, implementation) | `04-progress.md` |
| 5 | `bug-hunter` | `05-bug-hunt.md` |

If a stage skill isn't installed, say so in the final report and do that stage inline, following
the same template (see `references/handoff-templates.md`). Handoff files are numbered by the stage
that creates them; `04-progress.md` is the one living file, updated through stages 4 and 6.

Put the handoff files in a `review/` folder in the session scratchpad (or `/tmp/review-<project>/`
if there is none), **not** in the repository. They're working documents, and they can quote secrets
you come across while reading code.

**Resuming.** If the context was compacted, or you're unsure where the run stands, don't rely on
memory. List the `review/` folder, read `04-progress.md` if it exists, and check `git log` against
it, and look at `git diff` too (stage 4 work is uncommitted until the stage ends). The first stage without its
handoff file, or the first unchecked progress item, is where you resume. If the file and the code
disagree, trust the code and fix the file. Without git, diff the tree against the baseline copy from
preflight instead.

## Stage 0: Preflight

Before reviewing anything:

1. **Version control.** Check that the project is a git repository. The pipeline relies on git to
   undo, to commit per stage, to check old code in a scratch copy and to resume. If it isn't a
   repository, ask the user, offering `git init` plus a baseline commit of the current state. If they
   decline, copy the tree to the scratchpad as the baseline, skip the commits, and say in the
   report that nothing was committed.
2. **Read the house rules.** That means the global and project agent-instruction files (CLAUDE.md,
   AGENTS.md), plus any server or ops docs they point to: resource limits, sudo policy, restart
   policy, commit identity, docs you're expected to keep updated. Everything later must respect them.
3. **Proof baseline.** Every fix will need proof, so settle now what that proof is:
   - **A test suite exists:** run it in full once. If it isn't green, stop and tell the user.
     Hardening on a red baseline makes every later result ambiguous.
   - **No suite, but the code has a standard test runner** (pytest, vitest, PHPUnit…): set up a
     minimal one, as a dev dependency with the stack's usual layout and no restructuring. Commit it
     on its own and list it under "Decided on the user's behalf". An empty suite is a green baseline.
   - **Parts that can't reasonably be unit-tested** (shell scripts, compose files, CI, YAML config):
     pick the closest runnable check per area, such as a validator, linter, dry run or small
     reproduction script. Run it once and record its current output as the baseline. Fixes must not
     add failures.
   - **Nothing runnable at all:** ask the user before starting. Review, plan and fixes still work,
     but none of the fixes can be proven, so the pipeline's main promise doesn't hold.
4. **Clean commit point.** Run `git status`. Commit or set aside anything that belongs to the
   previous task (only what the user sanctioned), so each pipeline stage becomes its own commit.
   Don't sweep unrelated pre-existing changes into your commits. Starting the pipeline authorises
   these local commits; it does not authorise pushing.
5. **Bound the test runs.** Wrap every run so a deadlocked test can't wedge the session: a
   container memory/CPU cap if the project uses one, *and* an in-process timeout
   (e.g. `timeout 240 pytest …` inside the container). Fixes to locking, retries and timeouts are
   exactly the kind that surface as a hanging test, so expect hangs.
6. **Know the deploy story.** Does the project run somewhere (compose, service)? Then stage 4 and 6
   end with deploy plus a smoke check. Check the ops rules about restarting shared services first.

## Stage 1: Hostile review

Load `hostile-review` and **re-read every file in scope from disk**, even files you wrote earlier in
the session. Code edited by scripts or earlier turns drifts from memory, and a review of remembered
code is fiction. Keep a list of what you did and didn't read.

Aim the review at what this system can actually do to its users. For something that acts on the
user's behalf (posts, payments, deletes, emails), "can it do something unintended?" outranks style.
Number the findings (1.1, 2.3, …) so the later stages can refer to them. End with the skill's VERDICT,
naming 3–5 blockers.

## Stage 2: Ambassador verdicts

Load `project-ambassador` in answer mode. Rule on **every** finding: ACCEPT, ACCEPT-modified or
REJECT, each with a one-line rationale grounded in project intent, conventions or constraints.

- **Verify live state** before ruling on anything operational: which channels or services are active,
  what's deployed, what the data looks like. Check the real system, not the docs.
- State the project intent that governs the rulings in 3–5 bullets at the top (for example "never
  do something unintended on the user's behalf outranks convenience"). The staff plan depends on it.
- **"Decided on the user's behalf" is a required section.** Any ruling that changes UX, removes a
  feature, adds infrastructure or trades one of the user's preferences for another goes there, and
  it's repeated in the final report. The user delegated the decision, not the knowledge of it.
- Rejections are fine and expected (e.g. "external alerting: out of scope, follow-up").
  Rubber-stamping everything is a smell.

## Stage 3: Staff plan

Load `staff-review`, but produce an **implementation plan**, not a pass/fail review:

- Verdict line, then the top 5 risks *of the fixes themselves*: interactions, migrations, behaviour
  changes. Example: "a job skipped because it was cancelled must not count as a failure for the
  auto-pause".
- Group into phases in dependency order: core safety (data model, domain logic) → interface layer → robustness →
  ops/deploy. Schema changes go first and stay additive.
- For each item: the files and functions touched, the design in 1–3 lines, and **the test that will
  prove it** (or, where preflight found no test is possible, the check that will).
- Prefer real state (columns, flags) over parsing strings, when the UI or other logic branches on it.
- Call out anything that needs the user (privileged commands, external accounts) so it can be
  prepared as a paste-ready line rather than blocking the pipeline.

## Stage 4: Implement

Work phase by phase. After each phase, run the full suite.

Before writing any code, create `04-progress.md` with one checkbox per plan item, grouped by phase
(see the template). Update it **as you go, not at the end**: tick an item once its fix and test
are in, note the test name, and record deviations from the plan, deferrals and blockers the
moment they happen. After each phase's suite run, write the test count under the phase, and add
the commit hash once the stage is committed. This file is what lets the longest stage survive a compaction, and it's the
source for the final report.

**Every fix gets a test that would fail without it.** Where preflight settled on a runnable check
instead, the same rule applies: the check must fail, or report the problem, on the old code. Record
each fix's proof in `04-progress.md` as **tested** (test name), **checked** (which check) or
**unverified** (why). When a whole batch passes on the first run, be suspicious, not pleased, and
check each test's discriminating power:

- Read the test against the *old* code path. Would it actually have failed? A common false
  positive is a test that exercises the safe path (e.g. a same-origin Referer when checking a
  cross-origin redirect fix). Rewrite such tests to hit the fixed function directly with the hostile input.
- If you want to execute old code, copy the repository to a scratch directory or git worktree and
  revert the fix there. **Never `git stash` the live working tree to test old code.** If that run
  hangs or dies, your fixes are stranded in the stash while the tree shows old code, and every later
  command runs against it.

Then:

- Deploy (if the project deploys) and smoke-check: health endpoint, each main page or command,
  resource limits actually applied (`docker inspect`, not the YAML), and one negative check per
  security fix (e.g. a cross-origin POST returns 403).
- Update the docs the house rules require (README design rules, ops docs), then commit with a message
  that maps changes to finding numbers.

**Environmental blockers** (permissions, missing mounts, hosts you can't reach): diagnose until you
know the cause or have ruled out the obvious. Don't widen permissions on sensitive paths to get
unstuck. Take the path the environment already supports, write down the quirk in the ops docs, make
the failure *visible* in the product (a dashboard warning beats a silent retry loop), and hand the user
one paste-ready command. Example: a container can't write to a network share that the host can.
Resolve it with a host-side mount line for the user to paste, plus a visible "backup failed" state
in the product until they've run it.

## Stage 5: Bug hunt (recon only)

Load `bug-hunter`. Hunt for defects **not already in 01**, since those are fixed. Stay in recon mode:
don't fix during the hunt.

Proof is a failing test (or a failing check, for code preflight found untestable). Write each candidate as a test in a dedicated regression file (for example
`tests/test_bughunt.py` with `test_bh001_…`, or the equivalent in the project's test framework)
and run the file. The test is **supposed to fail**:

- Fails → Confirmed Bug.
- Passes → drop it or downgrade it to Latent Risk. Your theory was wrong, which is useful.
- Can't be tested (timing, external systems) → Latent Risk, with the static proof written down.

Write `05-bug-hunt.md` in the bug-hunter report format, including the coverage section (what you
didn't hunt).

## Stage 6: Final fix round

Add a "Final fix round" section to `04-progress.md` with one checkbox per BH finding you'll fix,
and list the latent risks you're leaving (with the reason). Fix every confirmed bug and every latent
risk that's cheap to fix, ticking items as you go. The bug-hunt tests are now the regression tests;
they must all pass. Run the full suite, deploy, smoke-check and commit ("Fix bug-hunt findings: …"
with the BH numbers).

## Stage 7: Report and ping

Build the report from the handoff files, especially `04-progress.md`, not from memory. Every item
not ticked there appears under "not done". Update the persistent memory and ops docs with anything durable (new services, quirks, decisions),
then send the user a push or desktop notification if the agent has one (e.g. PushNotification).
Lead with what they must act on, under 200 characters:
`review pipeline done: 24 fixed, 118 tests pass, deployed. 1 action: run the mount command in the report`.

The final message, in this order:

1. One-line outcome (findings fixed, test count, commits, deployed or not).
   If not every fix was tested, say how many were tested, checked and unverified.
2. A step table: stage → what it produced (counts, highlights).
3. The 4–6 most important fixes, in plain language (what can no longer go wrong), each with its
   proof label.
4. **Decided on your behalf**, from stage 2, with how to reverse each.
5. **Actions for you**, each a paste-ready command.
6. Anything not done or not verified, stated plainly.

## When to stop and ask

Only for things the user must own: anything irreversible or outward-facing that isn't covered by
their instruction (publishing, deleting user data, force-pushing, restarting shared services the
house rules protect), pushing to a remote, credentials, a red test baseline, a project that isn't a
git repository, and a project with nothing runnable to prove fixes with. Everything else, including design
trade-offs, goes through the ambassador and gets reported.

## Reference

- `references/handoff-templates.md`: the shape of each handoff file, with illustrative examples.
