# team-review

An agent skill that reviews a spec, design or plan and then fixes it. It chains three other skills from this repository: a reviewer with fresh eyes critiques the document (`staff-review`, or `hostile-review` first if you want it thorough), the `project-ambassador` decides which findings your project agrees with, and the agent writes every accepted one into the document.

The skill file is written for the agent (`SKILL.md`), but this file is intended for you as the user.

> **This skill edits your document, not your code.** "Implement every recommendation" means the spec, design or plan gets rewritten. Nothing the document describes gets built. To review and fix code, use [`review-and-harden`](../review-and-harden/).

## Install

Install the skill together with the three skills it uses:

```bash
skill-add team-review staff-review hostile-review project-ambassador
```

Or install the `code_development` bundle, which includes all four:

```bash
skill-bundle-add code_development
```

If one of the three is missing, the agent does that step itself, but without the method that skill brings. It will tell you so in its report.

| Skill | What it does in the loop |
|---|---|
| [`staff-review`](../staff-review/) | Reviews the document like a senior staff engineer: does it hold up, does it fit the code that is there |
| [`hostile-review`](../hostile-review/) | Thorough depth only. Goes first and tears the document apart, ranked by severity |
| [`project-ambassador`](../project-ambassador/) | Accepts, adjusts or rejects each finding, based on what your project is for |

## Use

```
/team-review [quick|thorough] [document]
```

```
/team-review thorough docs/specs/importer.md
/team-review quick the plan
/team-review
```

You can also just describe it: "run a staff-review on the plan and let the ambassador judge its findings, implement every recommendation".

There are two depths:

```
quick:     staff-review → ambassador rules on every finding → revise → report

thorough:  hostile-review → ambassador rules on the critical findings → revised draft
             → staff-review → ambassador rules on every finding → final version → report
```

Quick is one review round. Thorough is two, and costs roughly double the tokens and time. If you don't say which you want, the agent asks. It also asks which document you mean if that isn't clear. After that it runs to the end without checking in.

## What you need

- **A document in a file.** If your plan only exists in the conversation, the agent writes it to a file first and tells you where.
- **The project the document is about.** The reviewer checks what the document claims against the actual code. A spec that says "the importer already deduplicates" when it doesn't is a finding.
- **Your project's intent in writing.** The ambassador rules from your CLAUDE.md or AGENTS.md, README, docs and what you said in the conversation. The less of that there is, the more it has to guess or ask.

## What happens to your document

- **It is edited in place.** There are no `-v2` or `.final` copies. The result should read as if it had been written correctly the first time, with no "updated after review" notes.
- **You can always get the original back.** If the file is committed in git with no pending changes, git has it. Otherwise the agent saves a copy before the first edit and gives you the path.
- **Nothing is committed** unless you ask.
- **Only accepted findings go in.** The agent doesn't add its own improvements along the way. If it notices something the reviewer missed, that goes in the report.

## Why the reviewer starts from scratch

Each review is done by a separate agent that sees only the document and the project. It doesn't see your conversation, the reasoning behind the document or the previous round's findings. That is on purpose: whoever builds from the document won't have that reasoning either, so anything that only makes sense with it is a gap in the document.

It also means the reviewer will raise things your project has already decided. That is what the ambassador is for, and why some findings get rejected.

In the thorough depth, the ambassador only rules on the critical and high findings of the hostile review. A hostile review is excessive by design, and that round is for fixing what would sink the document. The smaller findings are listed in the report, and the second reviewer gets a clean look at the revised draft.

## What you get back

The revised document, and a short report with:

- the counts: findings, accepted, rejected, not judged
- the changes that matter most, in plain language
- **what was decided on your behalf**, with the alternative that wasn't chosen. For example, the ambassador may have accepted a finding that drops a feature or changes the scope.
- **what was rejected and why**, so you can overrule it
- open questions that ended up in the document
- how to see the diff or restore the original

## When it stops to ask

Before it starts: which depth, and which document, if you didn't say. During the run: only if the ambassador can't answer something that a critical or high finding depends on. Everything else it decides and reports.
