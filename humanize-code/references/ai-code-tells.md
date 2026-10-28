# AI Code Tells

Patterns that mark code as machine-written. Each one costs a human reader time. None is a bug on
its own, so fixing one must never change behaviour.

Treat each as a lead: check it in context before acting. A pattern the repo uses deliberately and
consistently (for example, a documented plugin interface with one built-in implementation) is a
convention, not a tell.

## 1. Comments

| Tell | Looks like | Action |
|---|---|---|
| Narration | `# Step 1: validate input`, `// Loop through the items`, `// Return the result` | Delete. If the steps are real phases, extract named functions instead. |
| Restating docstrings | `"""Gets the user by id. Args: id: the id. Returns: the user."""` on `get_user(id: int) -> User` | Trim to what the signature can't say, or delete. |
| Changelog comments | `// Updated to use the new API`, `# Changed per request`, `// Now handles X`, `// FIXED:` | Delete. History belongs in git. |
| Hedging | `// This should work`, `# Just in case`, `// For now`, `# To be safe` | Delete. If there is a real reason, write the reason. |
| Commented-out code | Old implementations kept "for reference" | Delete. |
| Banner blocks | `# ========== HELPER FUNCTIONS ==========` in a 120-line file | Delete, or split the file if the sections really are separate concerns. |
| Emphatic comments | `// IMPORTANT: ...`, `// NOTE: ...` on ordinary code | Keep the fact if it matters and drop the shouting. |
| Placeholder TODOs | `// TODO: add error handling`, `# TODO: implement` over code that works | Delete, unless it names a real known gap. |

## 2. Defensive noise

| Tell | Looks like | Action |
|---|---|---|
| Swallowed errors | `except Exception: pass`, `catch (e) {}`, `catch { return null }` | Let it propagate, or catch the specific error that can actually happen. Only change this when callers can't observe the difference. If they can, report it as a finding instead. |
| Log-and-continue | `except Exception as e: logger.error(e)` then carrying on with bad state | Same as above. |
| Impossible-case guards | `if x is not None` on a value that can never be None; `isinstance` on typed params; `?.` on guaranteed objects | Remove after checking every caller. |
| Masking fallbacks | `config.get("port", 8080)` when the key is required; `|| []` hiding a missing response | Keep the default only if it's intended behaviour. Otherwise report it; don't silently change it. |
| Redundant validation | The same input validated in three layers | Validate at the boundary, once. |
| Retry/timeout soup | Retry wrappers on local, deterministic calls | Remove. |

## 3. Speculative architecture

| Tell | Looks like | Action |
|---|---|---|
| One-product factory | `create_handler(type)` with a single branch | Construct directly. |
| One-implementation interface | `BaseStorage` / `IStorage` with one subclass and no plugin contract | Collapse, unless it's the test seam or a documented extension point. |
| Unused options | Parameters, flags and config keys that no caller ever sets | Remove, if they're not public API. |
| Wrapper that adds nothing | `def fetch(url): return requests.get(url)` | Inline. |
| Premature layers | `service` → `manager` → `handler` → `repository` for one SQL query | Collapse to the layers the code actually needs. |
| Compatibility shims for nothing | Aliases, deprecated wrappers or migration paths for code that was never released | Remove. |
| Manager/Helper classes | Classes with no state that only group functions | Plain module functions. |

## 4. Naming

| Tell | Looks like | Action |
|---|---|---|
| Hype words | `enhanced_`, `robust_`, `advanced_`, `smart_`, `comprehensive_`, `optimized_`, `improved_` | Name what it does. |
| Version suffixes | `parser_v2.py`, `utils_new.js`, `handle_fixed()`, `final_`, `_old`, `_backup` | Keep one version under the plain name. Delete the dead one. |
| Vague verbs | `handle_data`, `process_result`, `do_stuff`, `manage_items` | Name the operation: `parse_invoice`, `dedupe_contacts`. |
| Generic nouns | `data`, `result`, `info`, `obj`, `temp`, `item` for domain values | Name the content. Short loop variables are fine. |
| Over-long names | `get_user_data_from_database_by_id_safely` | Shorten to the distinguishing part. |

## 5. Sprawl

| Tell | Looks like | Action |
|---|---|---|
| Duplicated helpers | The same 5–20 lines in several files, often with small drift | Merge into one, in the module that owns the concept. Check the drift first: is it a bug or deliberate? |
| `utils` dumping ground | `utils.py` / `helpers.ts` holding unrelated functions | Move each function next to its callers or into a module named for its concept. |
| God file | One file with several responsibilities, typically 500+ lines | Split by responsibility (see restructuring playbook). |
| Artefact files | `IMPLEMENTATION_SUMMARY.md`, `CHANGES_MADE.md`, `test_output.txt`, `example_usage.py`, `demo.py` in the repo root | Delete, or ask the user if one might be wanted. |
| Parallel scripts | `run.sh`, `run_new.sh`, `start.sh` doing the same thing | Keep one. |
| Dead code | Unreferenced functions, unreachable branches, unused imports | Remove, after a repo-wide search including dynamic lookups (string-based dispatch, reflection, entry points in packaging config). |

## 6. Output and logging

| Tell | Looks like | Action |
|---|---|---|
| Emoji logging | `print("✅ Done!")`, `log.info("🚀 Starting…")` | Plain text, at the level the repo uses elsewhere. |
| Step logging | A log line before and after every operation | Keep the lines that help diagnose failures. |
| Print debugging | `print(f"DEBUG: {x}")` left in place | Delete, or turn into a debug-level log if it's useful. |
| Chatty messages | `"Successfully successfully processed all items!"` | Short and factual. Run user-facing strings through `humanize`. |

## 7. Tests

| Tell | Looks like | Action |
|---|---|---|
| Testing the mock | A test that asserts the mock returned what it was told to return | Report it. Rewriting tests is out of scope unless the user approved it in the plan. |
| Mirror tests | Tests that re-implement the function to compute the expected value | Report it. |
| Narrated tests | `# Arrange`, `# Act`, `# Assert` in every three-line test | Delete the labels. |

Test *changes* are only allowed when they're pure fallout from an approved move (import paths).
Everything else in this section is reported, not fixed.

## 8. Signs in the shape of the code

These are harder to grep. Look for them while reading:

- Every function the same length and structure regardless of what it does.
- Uniform try/except around every call, whether or not it can fail.
- Type annotations that are wrong or `Any` everywhere, added for decoration.
- Constants extracted for values used once (`MAX_RETRIES_FOR_THIS_ONE_CALL = 3`).
- A `main()` that's a numbered list of calls mirroring the comments above it.
- Ubiquitous `**kwargs` / `...args` pass-through that no caller uses.
