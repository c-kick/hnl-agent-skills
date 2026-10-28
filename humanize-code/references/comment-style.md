# Comment Style

The reader is a competent developer who knows the language. Comments annotate only what that reader
can't get from the code: purpose at the module level, the public contract, and the reasons behind
non-obvious decisions.

## Amount

- **Module / file header.** One to three lines: what this file is responsible for, and where it
  sits in the system if that isn't obvious. Every source file that holds real logic gets one.
  Trivial files (re-exports, constants, config) may skip it.
- **Public API.** A one-line summary in the language's standard doc format. Add parameter or return
  notes only when the name and type don't say it all: units, ranges, ownership, side effects, what
  `None`/`null` means, what it raises or throws.
- **Private functions.** No doc comment unless the name can't carry the purpose.
- **Inline.** A single `//` or `#` line, only for *why*: a workaround, a constraint, an ordering
  requirement, a surprising edge case, a reference to a spec or ticket.
- **Obvious blocks get nothing.**

Never write examples, usage blocks, multi-paragraph prose, bullet lists describing a block, or
restatements of the signature. If a block needs a paragraph to be understood, restructure the code
or name the pieces better.

## Language formats

Use the language's own standard. Where a companion skill for that language is installed, follow it
for syntax and tags, and this file for amount (see "Precedence" in `SKILL.md`). Match whatever
variant the repo already uses (e.g. Google versus NumPy docstrings) instead of introducing another.

| Language | Standard | Module header | Public API |
|---|---|---|---|
| Python | PEP 257, types in PEP 484 hints (not in docstrings) | Module docstring, one line | `"""Summary line."""`; `Args:`/`Raises:` only for non-obvious items |
| JavaScript | JSDoc | `/** @file … */` or a leading `//` line, as the repo does | `/** Summary. */` on exports; `@param`/`@returns` with types, since JS has none |
| TypeScript | TSDoc | Leading `//` or `/** … */` line | `/** Summary. */` on exports; no types in tags (the signature has them) |
| PHP | PHPDoc (PSR-5/PSR-19) | File or class docblock, one line (plus `@package` if the repo uses it) | `/** Summary. */`; `@param`/`@return` only where native types are insufficient, unless `php-documentation-standards` or the repo requires them |
| Go | Godoc | `// Package x …` in one file per package | `// Name does …` on exported identifiers |
| Rust | rustdoc | `//! …` | `/// …` on public items; `# Panics` / `# Errors` / `# Safety` sections when they apply |
| Java / Kotlin | Javadoc / KDoc | Class doc, one line | `/** Summary. */`; `@throws` for checked exceptions |
| C# | XML doc comments | — | `/// <summary>…</summary>` on public members |
| Shell | Header comment | `# script-name — what it does` plus a usage line | Function comment only when args aren't obvious |
| CSS / SCSS | `scss-standards` if installed | `//` line per partial | — |
| YAML / config | — | One line stating what reads this file | `#` on non-obvious keys only |

## Section dividers

Only in files that are long for a good reason and whose sections the reader will jump between. Use
the terse form the language community uses (`// --- Parsing ---`, `# region Parsing` in C#,
`// MARK: - Parsing` in Swift). Never in a file that's short enough to read at once, and never as a
substitute for splitting a file with several responsibilities.

## Rewrites

| Before | After |
|---|---|
| `# Loop through users and check if active` | *(nothing)* |
| `// Step 2: Parse the response` | *(nothing; or extract `parseResponse()`)* |
| `"""This function calculates the total price of all items in the cart and returns it."""` | `"""Cart total including VAT, in cents."""` |
| `// IMPORTANT: Must call init() first!!!` | `// Requires init(): the pool is created there.` |
| `// Updated to fix the race condition` | `// Lock before read: the poller writes from another thread.` |
| `/** @param {string} name The name. @returns {User} The user. */` on `findUser(name: string): User` | `/** Case-insensitive; returns the first match. */` |

## Wording

Comments are prose too. Keep them plain: no hype words, no "simply", "just", "easily", no emoji,
no exclamation marks. Present tense, describing what the code does or requires, not what someone
did to it.
