---
name: team-review
description: >
  Review-and-revise loop for a spec, design or plan: a fresh reviewer (staff-review, or
  hostile-review first for the thorough depth) critiques the document, the project-ambassador rules
  on the findings, and every accepted recommendation is written into the document in place. Use this
  whenever the user invokes /team-review, or asks to chain these skills on a document ("run a
  staff-review on the plan and let the ambassador judge its findings, implement every
  recommendation", "hostile-review the spec, let the ambassador judge, write a revised spec, then
  staff-review it"), or asks to "team review", "review and revise", "pressure-test and fix" or
  "tighten up" a spec, design or plan before building it. Prefer this over running staff-review or
  hostile-review alone when the user wants the document *improved*, not just critiqued. For
  reviewing and fixing code, use review-and-harden instead.
---

# Team Review

A review loop for a document that describes work still to be done: a **spec**, a **design** or a
**plan**. A reviewer with fresh eyes finds the problems, the project-ambassador decides which of
them the project agrees with, and you write the accepted ones into the document.

```
quick:     staff-review → ambassador rules on every finding → revise → report

thorough:  hostile-review → ambassador rules on the critical findings → revised draft
             → staff-review → ambassador rules on every finding → final version → report
```

**This skill only edits the document.** "Implement every recommendation" means changing the spec,
design or plan. It never means building what the document describes, even when a finding says
"add a retry here": that becomes a line in the document.

## Usage

```
/team-review [quick|thorough] [document]
/team-review thorough docs/specs/importer.md
/team-review quick the plan
/team-review
```

## Requires

This skill orchestrates three other skills from this repository. Install them alongside it:

```bash
skill-add team-review staff-review hostile-review project-ambassador
```

(`skill-bundle-add code_development` installs all four.) Each one brings its own method and
output format; this file only adds the order, the handoffs and the rules for revising. If one of
them isn't installed, do that step yourself in its spirit and say so in the report.

## Step 0: Settle the two inputs

**Which document.** Take it from the request: a path, or "the spec/design/plan" meaning the one
this conversation has been working on. If nothing was named, look at the conversation and at where
the project keeps such documents. Only ask when there is more than one real candidate.

The reviewer works from a file. If the document exists only in the conversation (for example a
plan you just presented), write it to a file first: where the project keeps such documents, or the
session scratchpad if it has no such place. Tell the user where it went.

**Which depth.** If the user said it, use it:

| The request says | Depth |
|---|---|
| "quick", "staff-review" only, one review named | quick |
| "thorough", "full", "hostile", both reviews named | thorough |
| nothing about depth | **ask** |

When you have to ask, use the agent's interactive question tool (`AskUserQuestion` in Claude Code,
`request_user_input` in Codex), not a question in chat. Offer both depths with what each one costs:
quick is one review round, thorough is two rounds and roughly double the tokens and time. If the
document is also unclear, put both questions in the same call. Don't pick a depth yourself.

After this step, run to the end without check-ins. The ambassador makes the judgment calls and the
report shows them.

## Step 1: Protect the original

The document is edited in place, so the user needs a way back to the version they wrote.

- **Tracked in git with no uncommitted changes:** git has the original. Nothing to do.
- **Anything else** (untracked, modified, not a repository): copy the file to the session
  scratchpad before the first edit and give the full path of that copy in the report.

Don't commit anything unless the user asked for it.

Keep your working notes (findings, verdicts) in a `team-review/` folder in the scratchpad, not in
the repository. Write each round's findings and verdicts there as soon as you have them. If the
context is compacted mid-run, that folder and the document's diff tell you where you were.

## Step 2: Review with fresh eyes

Hand each review to a **fresh subagent**. It gets the document and read access to the project, and
nothing else: no conversation history, no explanation of why the document says what it says, no
earlier findings, no hint of what you expect it to find. An author's reasoning that isn't in the
document doesn't exist for the people who will build from it, so the reviewer shouldn't have it
either. In the thorough depth, the second reviewer is a new subagent, not the first one continued.

Brief it along these lines:

```
Load the <staff-review | hostile-review> skill and review this <spec | design | plan>:
<absolute path>

You are reviewing the document, not code. Read all of it, then check what it claims against the
project: the files, functions, data and conventions it names or relies on. A claim that doesn't
match the code is a finding.

<the lens for this document type, from the table below>

Report in the skill's own output format, with these additions:
- Number every finding (F1, F2, …) and give each a severity: critical, high, medium or low.
- For each finding: where in the document (section or quote), what is wrong, why it matters,
  and the concrete change to the document that would fix it.
- List what you read in the project and what you did not check.
Do not edit any file.
```

| Document | What the reviewer should press on |
|---|---|
| **Spec** | Is every requirement unambiguous and testable? What is missing, contradictory or out of scope but assumed? Could two people build different things from it? |
| **Design** | Boundaries, data flow, state, failure modes, security, migration from what exists today. Does it fit the code that is actually there? Is anything built that nobody needs yet? |
| **Plan** | Order and dependencies of the steps, steps that are too big or too vague to execute, missing verification per step, rollback, what breaks halfway through. |

If the agent has no subagent tool, or the subagent can't load the review skill, run the review in
the main session: load the skill, re-read the document from disk (not from memory), and do the same
work. Say in the report that the review was not independent.

When the findings come back, save them to the notes folder before doing anything else. Don't
filter, merge or soften them. Deciding what counts is the ambassador's job, not yours.

## Step 3: Ambassador rulings

Load `project-ambassador` in the main session and put the findings to it. It answers for the
project: its goals, constraints, conventions and what the user has said they want, including
earlier in this conversation.

Each finding it rules on gets one of:

- **ACCEPT**: make the change the reviewer proposed.
- **ACCEPT-modified**: the problem is real, but the project wants a different fix. State the fix.
- **REJECT**: with a one-line reason grounded in the project (out of scope, contradicts a stated
  constraint, already covered in section X, solves a problem this project doesn't have).

Which findings it rules on depends on the round:

- **Quick, and the second round of thorough:** every finding.
- **First round of thorough (after the hostile review):** the critical and high findings. A
  hostile review is deliberately excessive, and this round is for fixing what would sink the
  document, not for polishing it. List the medium and low findings in the notes as "not judged".
  Don't pass them to the second reviewer. If they still matter after the revision, a fresh reviewer
  will find them again.

Rules for the rulings:

- **Check before ruling.** If a finding says the document contradicts the code, look at the code.
  A ruling based on what the document says about the code is worthless.
- **Rejecting is normal.** A reviewer without context will raise things the project has already
  decided. Accepting everything is a sign the ambassador isn't doing its job. So is rejecting
  everything.
- **Stay consistent across rounds.** If the second reviewer raises something the first-round
  ruling rejected, the earlier ruling stands unless the new finding brings a new argument.
- **Mark decisions made for the user.** A ruling that changes scope, drops or adds a feature,
  picks between real alternatives or trades one of the user's stated preferences for another goes
  in the report under "Decided on your behalf". The user delegated the decision, not the knowledge
  of it.
- **When the ambassador doesn't know,** it says so (that is part of its method). Collect such
  gaps, and ask the user once, through the question tool, only if a critical or high finding
  depends on the answer. Otherwise take the conservative reading, record the assumption in the
  document as an open question, and report it.

Save the verdicts to the notes folder.

## Step 4: Revise the document

Write every ACCEPT and ACCEPT-modified into the document. All of them: this step has no
"left for later" pile. If an accepted change turns out to be impossible to write down (it needs
information nobody has), turn it into an explicit open question in the document and report it.

- **Edit in place, in the document's own voice and structure.** The result should read as if it
  had been written correctly the first time. No "updated after review" notes, no changelog section,
  no finding numbers in the text, unless the document already keeps a revision history.
- **Change what the ruling covers and nothing else.** Don't use the revision to slip in your own
  improvements. If you see something the reviewer missed, add it to the report instead.
- **Follow each change through.** A fix in one section usually has consequences elsewhere: a
  renamed concept, a step that moved, an estimate or an acceptance criterion that no longer holds.
- **Re-read the whole document when you're done.** Patched documents contradict themselves. Check
  that the sections still agree with each other, that every reference still points somewhere and
  that the accepted changes are all actually in the text. Tick each one off against the verdicts.

In the thorough depth, this step runs twice: once to produce the revised draft that the staff
reviewer sees, and once to produce the final version. Then go back to step 2 for the second round
with a new subagent.

## Step 5: Report

Build the report from the notes folder and the document's diff, not from memory. Keep it short:

1. **Outcome**, one line: the document, the depth, and the counts (for example
   `docs/specs/importer.md, thorough: 23 findings, 14 accepted and written in, 5 rejected, 4 not judged`).
2. **What changed**: the 3–6 changes that matter most, in plain language. What was wrong, and
   what the document says now.
3. **Decided on your behalf**: each one with the alternative that was not chosen.
4. **Rejected**: each finding in one line with the ambassador's reason, so the user can overrule.
5. **Not judged** (thorough only): the medium and low findings from the hostile round, one line each.
6. **Open questions** that ended up in the document, and anything you noticed yourself that no
   reviewer raised.
7. **How to see or undo it**: the diff command, or the full path of the copy of the original.
   Also say here if a review was not independent or a required skill was missing.
