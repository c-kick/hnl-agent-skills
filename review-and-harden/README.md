# review-and-harden

An agent skill that runs a full review-then-fix cycle on a codebase, mostly unattended. It chains four other skills from this repository: a `hostile-review` finds problems without pulling punches, the `project-ambassador` rules on each one, a `staff-review` turns the accepted ones into a phased plan, and the agent implements every fix with a test that proves it. Then it runs a `bug-hunter` for whatever the review missed, fixes those too, and reports back.

The skill file is written for the agent (`SKILL.md`), but this file is intended for you as the user.

> **This is an expensive skill.** It runs four other skills in turn, re-reads your codebase several times, runs your test suite over and over and implements every accepted fix. Expect it to use many times the tokens of a single review, and more the bigger your codebase. If you only want a list of problems, run `hostile-review` or `bug-hunter` on their own. If you ask for something vague like "review this", the agent checks with you before starting. If you ask for the full pipeline, it just runs.

## Install

Install the skill together with the four skills it uses:

```bash
skill-add review-and-harden hostile-review project-ambassador staff-review bug-hunter
```

Or install the `code_development` bundle, which includes all five:

```bash
skill-bundle-add code_development
```

If one of the four is missing, the agent does that stage itself, but without the method that skill brings. It will tell you so in its report.

| Skill | Stage | What it does in the pipeline |
|---|---|---|
| [`hostile-review`](../hostile-review/) | 1 | Tears the code apart: numbered findings, ranked by severity |
| [`project-ambassador`](../project-ambassador/) | 2 | Accepts, adjusts or rejects each finding, based on what your project is for |
| [`staff-review`](../staff-review/) | 3 | Turns the accepted findings into a phased plan, and names the risks of the fixes themselves |
| [`bug-hunter`](../bug-hunter/) | 5 | Hunts for bugs the review missed, and proves each one with a failing test |

## Use

Ask for "a full hardening pass" or "review and fix everything", or spell out the chain ("hostile review, ask the ambassador, staff plan, implement, then bug-hunt"). Then you can walk away: the pipeline is built to run to the end without you.

```
0 preflight → 1 hostile review → 2 ambassador verdicts → 3 staff plan
   → 4 implement (phased, test per fix) → 5 bug hunt (prove, don't fix) → 6 final fixes → 7 report + ping
```

## What you need

- **Ideally, a git repository.** The pipeline makes a lot of changes while you're away, and git is how you undo them. It also gives you one commit per stage. If your project isn't a repository, the agent offers to run `git init` and commit the current state first. You can say no; it then works without commits and says so in the report.
- **Tests help, but aren't required.** The pipeline proves every fix, and an existing test suite is the easiest way to do that. If your tests are already failing, it stops and tells you: hardening on top of broken tests would make every later result meaningless. If you have no tests, the agent sets up a minimal test runner for your language (and tells you it did). For things you can't really unit-test, like shell scripts, Docker Compose files or YAML config, it uses the closest check it can run, such as a validator, linter or dry run. If there's nothing it can run at all, it asks you before starting.
- **Your house rules in writing.** The agent reads your CLAUDE.md or AGENTS.md first and follows it: commit rules, what it may restart, what needs sudo. Anything you haven't written down, it will decide for itself.

## What happens to your project

- **Code changes, each with proof.** Every fix gets a test that would have failed before it, or a check that would have flagged the old code. The agent makes sure the proof really catches the old behaviour. If you had no tests, you end up with a test suite, and that alone can be worth the run.
- **Local commits, one per stage,** with messages that point to the findings they fix. Nothing is pushed.
- **A redeploy,** but only if your project already deploys somewhere (e.g. Docker Compose or a system service). Afterwards the agent checks that it's actually up and that the security fixes hold.
- **No review files in your repository.** The agent's working notes (findings, verdicts, plan, progress) go to its scratch directory. They can quote secrets it came across while reading your code. See [`references/handoff-templates.md`](references/handoff-templates.md) for what they look like.

A long run can outlast the agent's working memory. The agent keeps a progress file as it goes, so it can pick up where it left off instead of guessing.

## What you get back

A notification when it's done (if your agent supports one), and a final report with:

- what was fixed, how many tests pass, and whether it was deployed
- the most important fixes in plain language, each labelled **tested**, **checked** (and by what) or **unverified** (and why), so you know how far to trust it
- **what was decided on your behalf**, and how to undo each decision. For example, the ambassador may have rejected a finding, or accepted one that changes how something works for you.
- **actions for you**, each as a command you can paste
- anything that wasn't done or couldn't be verified

## When it stops to ask

Only for things that are yours to decide: anything irreversible or public your request didn't cover (publishing, pushing, deleting user data, restarting shared services), and credentials. Before it starts, it also asks if your project isn't a git repository, if your tests are failing, or if there's nothing it can run to prove its fixes. It asks all of that in one go, so you can still walk away afterwards. Every other decision goes through the ambassador and ends up in the report.
