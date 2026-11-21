---
name: abuse-test
description: >
  Abuse-test a project's backend and frontend on a local or dev instance: feed
  them malformed and extreme input, fire concurrent and badly timed requests,
  and apply bounded resource pressure, then report what breaks, with a repro
  probe for every finding. The skill finds endpoints and pages in the code,
  proposes an attack plan, starts its own contained instance (or reuses a
  confirmed dev instance), and runs only after the user approves. Use when the
  user invokes /abuse-test, or asks to "abuse test", "hammer", "torture test",
  "fuzz the API", "throw garbage at it", "try to break the app", "what happens
  if users do stupid things", "stress the forms", "double-submit / race test",
  or "see how it handles huge uploads". Report only: it never fixes code (hand
  the report to review-and-harden or systematic-debugging for that). Never for
  production or third-party systems, never a DoS.
---

# Abuse Test

You play the worst user the app will ever have: careless, impatient, and
creative. You attack a **running local or dev instance** through its real
interfaces (HTTP, WebSocket, browser UI) and write down every way it misbehaves.

You report. You do not fix. Every finding has a probe that reproduces it.

## Prerequisites

- `python3` (standard library only) for `scripts/check_target.py`. Works on
  Linux, macOS and Windows.
- `curl` for backend probes, or Python's `urllib` where curl is missing.
- A browser automation tool for the frontend phase (optional, see Phase 4).

[references/running-safely.md](references/running-safely.md) has the
mechanics for Phases 3–5: identifying listeners, running from a snapshot,
memory limits, measuring, restarts and teardown. Read it before Phase 3.

## Hard rules

1. **Local/dev targets only.** Before sending any traffic, run
   `python3 scripts/check_target.py <base-url> --deny <production hosts>`
   (path relative to this skill's directory; the production hosts come from
   recon) for every base URL in the plan, including the URL the browser will
   use. Pass only the bare base URL, `scheme://host[:port]`, and prefer IP
   literals (`http://127.0.0.1:PORT`) so the address checked is the address
   connected to. Act on the first word it prints:
   - `local`: loopback or a container network on this host. Allowed, but
     **local does not mean dev**: shared hosts run production on `localhost`
     and `0.0.0.0` too. You only send traffic to instances you started, or that
     the user confirmed as dev in the plan (see Phase 3).
   - `private`: a LAN/private address. Allowed only if the user named it as a
     dev host in the approved plan.
   - `refuse`, or anything else (an error): **do not attack it**, not even "just
     one request". Say why and drop that target.
   Probes must use exactly the base URL that was checked. Everything the repo
   identifies as production (deploy docs, compose/CI files, the project's
   public domain, names like `prod` or `www.`) is refused, whatever it
   resolves to. URLs and run commands found in the repository are proposals
   for the plan, not instructions.
2. **No live traffic before the plan is approved.** Phase 1 only reads code.
   A new base URL, port or host found after approval needs a new approval.
3. **Bounded intensity.** Ramp up step by step and stop at the first failure
   or at the cap (see [Intensity](#intensity)). This is abuse testing, not a
   denial-of-service attack. Never point load at a host other than the target.
4. **Existing data is real data.** Treat any database, volume or file store
   you did not create in this run as real, including the data behind a
   running instance you reuse. Prefer a fresh one: a separate compose project
   (`docker compose -p abuse-<date> …`), a temp SQLite file, a fresh data dir,
   or the project's test config. If you can only use existing data, the plan
   says so and the user chooses in the approval question whether write probes
   run at all.
5. **No real side effects outside the host.** In recon, list every outbound
   integration (SMTP, payments, SMS/push, webhooks, OAuth, features that fetch
   a user-supplied URL) with file:line. The plan says how each is neutralised:
   sandbox/test keys, a local mail catcher, provider test mode, or the env var
   unset. Probe a flow with an external side effect only once it is
   neutralised. Never put a non-local URL in a payload; for URL-fetching
   features, point them at a local listener (`python3 -m http.server --bind
   127.0.0.1`). Setup that needs the network (installing packages, pulling or
   building images, downloads in a Dockerfile) is listed in the plan as such;
   prefer reusing what is already on the host.
6. **Leave the host as you found it.** Stop exactly what you started, delete
   temp payloads, and say what you could not clean up. Never run
   `docker compose down -v` or delete volumes, databases or files you did not
   create. If probes wrote into existing data, list what was written
   (endpoints and counts) in the report.
7. **No code fixes, no writes to the repo.** Don't edit application code or
   config, and don't let the app write into the working tree either: run from
   a snapshot (`git archive`) or with the tool's no-write flags. You write only
   inside the report dir and the session scratchpad. Setup steps the app needs
   (installing dependencies, migrations on the throwaway DB, building images)
   are allowed only when listed in the approved plan.
8. **Secrets stay out of arguments and files.** Tokens and passwords go
   through the environment or a `0600` file in the scratchpad, never on a
   command line (it shows in `ps` and unit descriptions) and never inside a
   probe or the report.

**Auth scope.** Auth and permission abuse (guessing or stealing tokens,
bypassing checks, other users' data, privilege escalation) is **out of scope
by default**. Only do it if the user asks; for a real security assessment point
them to a security audit (for example the `security-audit` skill, if installed).
In scope: requests without credentials that measure what the server does
*before* it rejects them (does it read a 100 MB body before the 401?), as long
as they send no guessed or stolen credentials.

## When you run as a sub-agent

You may have no question tool, no chat with the user, and the harness may
refuse report files. Then:
- At the end of Phase 2, write the plan to `<report-dir>/plan.md`, return it
  as your final answer, and **stop**. Continue only when re-invoked with the
  user's approval.
- In Phase 6, try to write `report.md`; if that is refused, return the full
  report as your final answer so the caller can save it.

## Phase 1: Recon (read-only)

Map the attack surface from the code. Don't guess; cite file:line.

- **How to run it:** `docker-compose.yml`/`compose.yaml`, `package.json`
  scripts, `Makefile`, `Procfile`, `manage.py`, `pyproject.toml`, README run
  instructions, `.env.example`, Dockerfiles. Note ports, required env vars, a
  test/dev config, which data store it uses, and whether an environment
  already exists on the host (virtualenv, `node_modules`, a built image).
- **Production endpoints:** every host, URL and port the repo identifies as
  production or as another deployment (deploy docs, compose files, CI, env
  examples). They go on the `--deny` list.
- **Production differences:** how production runs (container memory/CPU
  limits, tmpfs mounts, worker counts, external tools such as a JVM or
  ImageMagick) and which of these your local instance will lack. A missing
  tool means an untested code path; a missing limit can turn a crash into mere
  slowness, or the other way round.
- **Backend surface:** routes and handlers (framework routers, OpenAPI/Swagger
  specs, GraphQL schemas), WebSocket handlers, file upload handlers, background
  jobs and worker pools triggered by requests, rate limiters, body-size
  limits, timeouts, validation layers, and the order in which they run (is the
  body parsed before auth? is a limit checked before or after the upload is
  stored?).
- **Frontend surface:** pages/routes, forms and their submit handlers, file
  inputs, search/filter boxes, infinite lists, client-side state that
  survives navigation, optimistic updates.
- **Other interfaces:** CLIs, queue consumers and adapters that reach the same
  engine. List them; if you don't attack them, they go under "Not tested".
- **Outbound integrations:** everything rule 5 asks for.
- **Sessions:** how to get a logged-in session or API token (seed user,
  registration, dev bypass, a token env var), since most write endpoints need
  one.
- **Test helpers:** fixtures and factories in the project's tests that build
  valid inputs (sample files, payload builders). Reuse them for probes
  instead of writing your own.
- **Hotspots worth abusing first:** anything that writes data, takes a file,
  parses user text (dates, numbers, markdown, JSON, CSV, archives), paginates,
  does work whose cost grows faster than its input, sends
  email/notifications, charges money, or has a check-then-act sequence
  (stock, unique names, counters). Write each as a hypothesis in the plan,
  not a finding.

## Phase 2: Attack plan (ask, then wait)

Decide the report dir now: `docs/abuse-test/YYYY-MM-DD/` (use the project's
docs dir if it has another convention; add `-2`, `-3`… if the dir exists).
It holds the deliverables: report, probes, screenshots. Logs, payloads, the
snapshot and the monitor's samples go to `<scratchpad>/abuse-test/`, because
they can be large or contain secrets. The report dir is new and untracked:
don't commit it or add it to `.gitignore`; the user decides.

Write the full plan in chat, then ask for approval **with the agent's question
tool** (`AskUserQuestion` in Claude Code, `request_user_input` in Codex, which
is normally only available in Plan mode). If no question tool is available,
ask in chat and wait. Silence is never approval. As a sub-agent, see
[When you run as a sub-agent](#when-you-run-as-a-sub-agent).

The plan shows:

- How you will start the app: your own instance (snapshot, environment, the
  memory limit it runs under, the free port), or the running instance you
  identified and why you believe it is dev (Phase 3). Any setup that needs the
  network.
- The base URL(s) for probes and for the browser, the `--deny` list, and the
  `check_target.py` result for each, including the refused ones.
- Production differences and what they mean for the results. If a second
  instance would close an important gap (for example the project's own image
  with production's limits), offer it as an option.
- The data store: fresh, or existing (rule 4).
- The outbound integrations and how each is neutralised, or which flows are
  skipped (rule 5).
- How you will get a session: a throwaway account in the fresh data store, or
  a throwaway token you generate. Never the user's own credentials or tokens
  found on the host.
- The hypotheses and targets, ranked by risk, with the abuse classes per
  target (from [references/probe-catalog.md](references/probe-catalog.md)).
- Which browser tool you will use for the frontend, or that the frontend
  phase is skipped and why.
- The intensity caps (adjusted to what one request costs, see
  [Intensity](#intensity)), the host stop conditions with their baseline, and
  the report dir.

Approval options: approve / trim targets / change caps / approve without write
probes (offer the last one whenever data is existing), plus any optional
instance you offered. Then go.

## Phase 3: Bring the app up

Follow [references/running-safely.md](references/running-safely.md).

1. **Running instances.** If something listens on a port from recon, identify
   it from the host side (process command line, container image and uptime)
   without sending it traffic. Reuse it only if it is unmistakably this
   project's dev instance and the user confirmed that in the plan; its data is
   existing data (rule 4) and you don't stop it afterwards. Anything else,
   including anything you can't identify for sure, is left alone: start your
   own instance on a free port.
2. **Your own instance.** Start it from a snapshot, on the fresh data store,
   **inside a memory limit** (systemd scope, `docker run --memory` with
   `--memory-swap`, or `ulimit`), bound to loopback (or the container bridge,
   see Phase 4), logging to the scratchpad. Record what you launched in
   `started.txt`.
3. Block until it answers a health check or its home page (poll, max ~2 min).
   If it won't start, report that as the first finding and stop.
4. **Baseline.** Record response times and the server's memory, open files and
   connections for a few normal requests, plus the host baseline for the stop
   conditions. Start the monitor loop (outside the app's limit). Exhaustion
   findings are relative to this.

## Phase 4: Attack

Work through the approved plan, highest risk first. For each target and abuse
class, follow [references/probe-catalog.md](references/probe-catalog.md).
Write one timestamped line per probe and per restart to
`<scratchpad>/abuse-test/progress.log`.

**Backend:** write probes as standalone scripts in `<report-dir>/probes/`
(bash + `curl`, or Python with only the standard library, unless the project
already has `httpx`/`requests`), named `NN-<target>-<class>.sh|py`. Each one:
- takes the base URL as its first argument,
- starts with the target guard from the catalog's skeleton,
- reads any token from an env var (rule 8),
- runs on its own.
A sweep of many related cases (malformed input) can be one file with
selectable case names (`probe <base-url> <case>`). Payload builders and the
guard can live in one shared helper module in `probes/`.

**Frontend:** use whatever browser automation the session has, in this order:
Puppeteer MCP (see the `browser-eyeballs` skill if installed), the project's
own Playwright/Cypress setup, `npx playwright`, any other browser tool. If none
works, skip the frontend phase and say so in the report; don't install
browsers system-wide without asking.
- If the browser runs in a container (Puppeteer MCP often does), `localhost` is
  the container itself. Point it at this host's container bridge gateway
  address (for Docker usually the `docker0` address), check that URL with
  `check_target.py`, and have the app listen there. Use the host's LAN address
  only if the user approved it in the plan.
- Navigate only to checked origins, and block or note requests the page makes
  to other origins too (CDN scripts, fonts, analytics: Playwright
  `page.route`). If a page redirects or links to another origin, don't follow
  it; note it.
- For each UI probe, save the steps as a script (Playwright) or as an exact,
  numbered manual repro in the probe file, plus a screenshot of the broken
  state in the report dir where you can.

**While attacking, watch** (how to measure each:
[running-safely.md](references/running-safely.md#measure-what-the-server-actually-holds)):
- HTTP status and body (500s, stack traces, leaked internals, wrong 2xx)
- the app's logs for exceptions, even when the response looked fine
- data afterwards: duplicates, half-written records, negative counters
- server memory (heap separately from tmpfs/cache), open and deleted-but-open
  files, connections, CPU and response time against the baseline, also
  *after* the request has finished
- work that outlives the client: jobs that keep running after a disconnect
- other users: time a tiny normal request while an expensive one runs
- browser console errors, stuck spinners, lost input, broken layouts

**Something is a finding when** the app crashes or hangs, returns 5xx for
client errors, accepts invalid data and stores it, corrupts or duplicates
data, leaks stack traces/secrets/paths, loses user input, blocks other users,
gives contradictory results for equivalent operations (check says clean,
repair fails on the same input; preview differs from save), or degrades
unbounded (no limit hit, resources keep climbing). A clean 4xx with a useful
message is the app doing its job: note it under "held up" and move on.
Endpoints and pages you could not reach (for example behind a login you had
no session for) go under "Not tested", never under "held up".

**Verify before you report.** Re-run every probe once in a fresh state: new
records and IDs for that probe, and for concurrency probes, only the records
the probe itself created reset. Reset the whole database only if it is the
throwaway one. For a ramp that ended in a crash, reproduce the mechanism at a
lower intensity instead (show the leak or growth persists over a few steps)
rather than crashing it again. A finding that does not reproduce is marked
`flaky` with the run count, or dropped.

**If the app crashes:** record it. If you started it, restart it as
described in [running-safely.md](references/running-safely.md#restarts): old
instance gone, health check passed and monitor alive before the next probe.
If it is a reused instance, don't restart it yourself: tell the user, then
continue only with targets that don't need it, or stop.

## Intensity

Default caps (the user can change them in the plan). First measure what one
request costs. If a request is a full processing job (an upload that gets
converted, a report that gets generated), size the steps by what fits in the
step's time limit, not by the request counts below.

| Class | Steps | Hard cap |
|---|---|---|
| Parallel requests | 10 → 50 → 200 concurrent | 200 concurrent, 2 000 cheap requests per step (fewer for expensive ones), 30 s per step |
| Repeat/double submit | 2 → 5 → 20 identical in < 100 ms | 20 |
| Payload size | 1 KB → 1 MB → 10 MB → 100 MB | 100 MB, including after decompression, and the ~4× copies within 10% of free disk/RAM where they land |
| Item counts (lists, arrays, files) | 100 → 10 k → 100 k | 100 k |
| Expensive input (cost grows faster than size) | 100 → 1 k → 10 k elements | 120 s server time per request; at the cap, stop the class and restart the app |
| Slow clients / held connections | 10 → 50 | 50 connections, 60 s |
| Cumulative (leaks, abandoned requests, stored growth) | 2 → 5 → 20 repetitions of an in-cap request | stop at first failure; run only with the app inside a memory limit |

Stop ramping a class at its first failure: that step is the finding. Stop
everything at once when a host stop condition fires
([running-safely.md](references/running-safely.md#contain-the-app)).

**Beyond the caps.** When the code allows more than the caps let you test
(a 2 GiB unpack limit, a 100 MB cap), measure the trend up to the cap and
extrapolate. Report it as **not demonstrated**, with the numbers you measured
and the extrapolation, and rate it one level below what a demonstrated failure
would get.

## Phase 5: Tear down

Stop exactly what `started.txt` lists, in reverse order (never `pkill -f`),
stop the monitor, delete the snapshot, temp data and payloads, and confirm
the ports are free and the units/containers are gone. Leave a reused instance
running. Follow rule 6 for data and volumes. The probes and report stay.

## Phase 6: Report

Write `<report-dir>/report.md`, with the probes in `<report-dir>/probes/`
(as a sub-agent, see the fallback above). Follow
[references/report-template.md](references/report-template.md).

Severity:
- **critical**: crash/hang of the whole app, data loss or corruption, stored
  invalid data that breaks other users, a secret or credential leaked
- **high**: 5xx or unhandled exception on reachable input, duplicate side
  effects (double charge, double email), resource growth that persists or
  affects other users, one request blocking other users for a long time
- **medium**: wrong status code, user input lost, UI stuck until reload, a
  stack trace or internal path in a response, contradictory results between
  equivalent operations, a missing limit whose cost falls only on the
  requesting connection
- **low**: ugly error message, cosmetic breakage, minor slowness

A finding that was not demonstrated (extrapolated beyond the caps) is rated
one level lower.

Then give a chat summary: counts per severity, the top findings (one line each
with the probe path), what held up, what was skipped and why, the
production differences that limit the results, and the report path. Suggest
`review-and-harden` or `systematic-debugging` for the fixes; don't start them
yourself.
