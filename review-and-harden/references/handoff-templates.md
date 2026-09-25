# Handoff templates

The shape of each handoff file. The examples use a hypothetical web app (HTTP API, database,
background job worker) to make the format concrete; the content is illustrative, not a checklist.

## 01-hostile-review.md

Follow the `hostile-review` output format. The pipeline relies on:
- Numbered findings `N.M` in themed sections, each with the offending code, **What it is**,
  **Edge case** (a concrete scenario) and **Fix**.
- `## VERDICT` ending with **Immediate actions required** (3–5 blockers).

Example finding, abbreviated:
```
### 1.2 Queued jobs still run after the user cancels them
**What it is:** Jobs are scheduled ahead of time, and nothing re-checks them when they execute.
**Edge case:** The user cancels an export at 14:58; it was queued for 15:00 and still emails the file.
**Fix:** In the worker, re-check the job's state right before executing; skip and log if cancelled.
```

## 02-ambassador-verdicts.md

```
# Project Ambassador: verdicts on the hostile review
Sources: <instruction files, memory, docs, live checks>. Live state: <what is actually running>.

## Project intent that governs these rulings
- <3–5 bullets, e.g. "never act on the user's behalf without their current consent outranks convenience">

## Verdicts
| # | Finding | Verdict | Ruling |
|---|---|---|---|
| 1.1 | CSRF | ACCEPT | Origin/Referer same-host check on non-GET; 403; tests. |
| 2.1 | Optional dependency blocks startup | ACCEPT, modified | Make it lazy; the feature that needs it shows "unavailable" instead. **Changes UX, so report it.** |
| 2.4 | No retry limit | ACCEPT; alerting REJECTED | Auto-pause after 3 failures; external alerting is out of scope, follow-up. |

## Constraints for the implementation plan
- <resource caps, privilege rules, commit identity, docs to update>

## Decided on the user's behalf
- <each UX/feature/infrastructure trade-off, with how to reverse it>

## Needs user input
- <blocking questions, or "none">
```

## 03-staff-plan.md

```
# Staff review: implementation plan
**Verdict:** approve-with-changes. <refinements to the ambassador's rulings>

## Top risks (of the fixes)
1. <interaction, e.g. a job skipped because it was cancelled must not count as a failure for the auto-pause>

## Design per item (in implementation order)
### Phase A: core safety
- **A1 (1.2)** <file:function> <design> *Test:* <what proves it>
- **A2 schema v2:** additive columns with defaults.
### Phase B: interface  ### Phase C: robustness  ### Phase D: ops

## Security notes / Testability
```

## 04-progress.md

The only handoff file that is edited over time. Create it at the start of stage 4 from the plan
and update it after every item, so a compacted or restarted session can pick up where it left off.
```
# Implementation progress
Plan: 03-staff-plan.md. Baseline: 64 tests green at a1b2c3d.

## Phase A: core safety (done: 71 tests green)
- [x] A1 (1.2) re-check job state before executing. Tested: test_cancelled_job_is_skipped
- [x] A2 schema v2, additive columns. Tested: test_migration_v1_to_v2_keeps_rows
## Phase B: interface
- [x] B1 (1.1) CSRF origin check. Tested: test_cross_origin_post_is_403
- [x] B4 (3.4) compose healthcheck. Checked: `docker compose config` + healthy within 30 s
- [x] B5 (4.1) log rotation in the entrypoint script. Unverified: needs a day of real logs
- [ ] B2 (2.3) <next item>
- [ ] B3 (3.1) DEFERRED: needs a privileged command; paste-ready line in the report

## Deviations from the plan
- B1: also covers PUT/DELETE, not only POST (the plan missed them).

## Blockers / actions for the user
- <paste-ready command, and what's visible in the product until it's run>

## Final fix round (stage 6)
- [ ] BH-001 <title>. Regression test: test_bh001_…
- Left as latent risk: BH-004 (<reason>)

Stage 4 commit: 4e5f6a7. Stage 6 commit: <hash>.
```

## 05-bug-hunt.md

Follow the `bug-hunter` report format. Each confirmed finding cites its failing test:
```
### [MEDIUM] BH-002: Upload filenames escape the storage directory
**Status:** Confirmed (test_bh002 writes uploads/../../escape.txt outside the storage root)
```
Include the risk map and an honest coverage section.
