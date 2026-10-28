---
name: interview-me
description: >
  Interview the user through the agent's native interactive question tool instead of
  asking questions inline in chat: multiple-choice answers per question (single choice,
  or a checklist when several answers apply), always with a free-text "Type something"
  option, navigated with the arrow keys. Use when the user invokes /interview-me or
  $interview-me, or says "interview me", "ask me", "quiz me on the options", "grill me",
  "ask me questions first", "let me pick", or otherwise wants to answer the agent's open
  questions interactively. Also use it on your own whenever you are about to ask the
  user questions inline in chat: ask them through the picker instead. Works in Claude
  Code (AskUserQuestion) and Codex (request_user_input).
user-invocable: true
---

# Interview Me

The user wants to answer your questions in the agent's **interactive question UI**, not
in chat. You show each question as a picker. The user moves between questions or
answers with the arrow keys and picks an answer, or types their own in the free-text
field.

**The one rule: never write a question in chat text.** No lists of questions, no
"(a)/(b)/(c)" options in a message, no "Let me know which you prefer". If you have a
question for the user, it goes through the question tool.

## Which tool

| Agent | Tool | Free-text option | Checklist (several answers) |
|---|---|---|---|
| Claude Code | `AskUserQuestion` | added automatically ("Other" / "Type something") | `multiSelect: true` |
| Codex | `request_user_input` | added automatically ("Other") | not supported, see below |

Don't add your own "Other" or "Something else" option. The tool already adds one, and a
second one is clutter.

If neither tool is available, see [When the tool is missing](#when-the-tool-is-missing).

## What to ask about

1. **A topic given after the command** (e.g. `/interview-me about the database schema`): interview the
   user on that topic. Work out what you need to know first. Read the relevant code or
   docs so your options are concrete and grounded, not generic.
2. **No arguments, and you have open questions** (the usual case: you just asked
   something inline, or you are about to make a call that is the user's to make): put
   *those* questions to the user through the tool. Don't add new ones.
3. **No arguments, nothing pending**: use the tool to ask what they want to be
   interviewed about. Offer 2–4 likely topics taken from the conversation so far.
4. **Not invoked, but you are about to ask the user something inline**: ask it through
   the tool instead. This only changes *how* you ask. Don't open an interview just
   because a decision is coming up, and don't add questions you wouldn't have asked.

Don't announce the mode or explain the rules. Go straight to the first tool call.

## Writing good questions

- **One decision per question.** Split compound questions ("which DB and should it be
  hosted?") into separate ones.
- **Self-contained.** The user may see only the question dialog, not your earlier text.
  Each question should name what it is about and, briefly, why it matters
  ("The importer keeps duplicates. How should it handle them?").
- **Short header**, max ~12 characters (e.g. `Auth`, `Storage`, `Scope`).
- **2–4 real options** (Codex: 2–3), each with a label of 1–5 words and a one-line
  description of what choosing it means or costs.
- **Options must be mutually exclusive** for single choice. If they aren't, it's a
  checklist question.
- **Recommend when you can.** Put your recommended option first and end its label with
  `(Recommended)`. Only do that when you actually have grounds for it.
- **Use previews for visual comparisons** (Claude Code): when options are code
  snippets, layouts, config variants or diagrams, add a `preview` to each option so
  the user can compare them side by side. Previews only work for single choice.
- **Don't ask what you can find out yourself.** Facts in the code, the docs or the
  conversation aren't questions. Ask about intent, preference, priorities and
  trade-offs.

### Single choice vs. checklist

- Use **single choice** when exactly one answer can apply (pick a library, pick an approach).
- Use a **checklist** (`multiSelect: true` in Claude Code) when several can apply
  together (which features to include, which platforms to support, which files to
  touch). Phrase it that way: "Which of these should the export include?"
- **Codex has no checklist.** Use single choice with the most useful combinations as
  options (e.g. `CSV only`, `CSV + JSON`, `All formats`), and say in the question that
  the user can type a custom combination in the free-text field.

## Running the interview

1. **Batch related questions**: up to 4 per call in Claude Code (3 in Codex). Put
   questions that don't depend on each other in the same call. A question whose
   options depend on an earlier answer goes in the next round.
2. **Read the answers literally.** Free-text answers are real answers. If one is
   unclear or opens a new branch, ask a follow-up *through the tool*.
3. **Keep going in rounds** until you have what you need. Don't pad with questions you
   don't need, and stop as soon as the open decisions are settled.
4. **Never ask "is that all?" or "shall I proceed?" through the tool.** When the
   interview is done, give a short summary in chat, one line per decision
   (`Storage: SQLite (you: "keep it single-file")`), then carry on with the task.
   In plan mode, finish the interview *before* presenting the plan.
5. **If the user declines or dismisses a question**, don't ask it again. Go with your
   best judgment and say in the summary what you assumed.

The mode ends with the interview. After the summary you go back to normal behaviour,
until the user asks for an interview again (or you are about to ask questions inline,
see case 4 above).

## When the tool is missing

Check your tool list, don't guess.

**Codex, Default mode:** `request_user_input` is normally only available in **Plan
mode**. Tell the user in one line and give them both ways to fix it:

- Switch this session to Plan mode with `/plan`, then run `$interview-me` again, or
- Enable the tool in Default mode (feature flag, still marked "under development"):
  ```toml
  # ~/.codex/config.toml
  [features]
  default_mode_request_user_input = true
  ```
  or start Codex with `codex --enable default_mode_request_user_input`.

**`codex exec` / non-interactive runs:** the tool doesn't work there at all. Say so.

**Any other agent without a question tool:** say that interactive questions aren't
available here.

In all of these cases, don't silently fall back to a wall of inline questions. After
the one-line notice, ask **only the first question** in plain text with lettered
options and an "or type your own" line, wait for the answer, then ask the next one.
