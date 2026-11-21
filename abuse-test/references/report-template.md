# Report template

```markdown
# Abuse test: <project> (<YYYY-MM-DD>)

**Target:** <base URL(s)>, <how it was run: compose / npm run dev / reused instance>
**Commit:** <git short hash, dirty or clean>
**Data:** <fresh compose project / temp DB / test config / existing data (write probes on or off)>
**Outbound:** <each integration and how it was neutralised, or which flows were skipped>
**Session:** <throwaway account / seeded test user / none (behind-login targets not tested)>
**Browser tool:** <Puppeteer MCP / Playwright / none: frontend skipped because …>
**Caps:** <defaults, or what the user changed>
**Differences from production:** <missing tools, different limits/workers, and which findings or code paths they affect>

## Summary

| Severity | Count |
|---|---|
| critical | n |
| high | n |
| medium | n |
| low | n |

<2–4 sentences: the biggest risk and the pattern behind most findings,
e.g. "no request body limit anywhere" or "no idempotency on writes".>

## Findings

### F01 [critical] <one-line title>

- **Where:** `METHOD /path` or page `/route` → handler `file.py:123`
- **Class:** malformed input | concurrency | resource exhaustion | inconsistent results
- **Repro:** `probes/01-orders-double-submit.sh <base-url>`
- **Expected:** <what a robust app does>
- **Actual:** <what happened: status, body excerpt, log excerpt, numbers>
- **Reproduced:** 2/2 runs (or `flaky`: 3/5, or reproduced at lower intensity: …)
- **Demonstrated:** yes, or `not demonstrated`: measured up to <cap>, extrapolated to <limit the code allows>
- **Likely cause:** <one line, cite code if you saw it; "unknown" is fine>
- **Evidence:** <screenshot path, redacted log excerpt, memory numbers>

…

## Held up

Short list of what was attacked and handled correctly (clean 4xx, limits
enforced, no duplicates), so the next run knows what's already covered.

## Not tested

What was in recon but skipped (out of scope, no browser tool, real data,
user trimmed it, beyond the caps, other interfaces such as a CLI, production
hosts refused) and why.

## Environment notes

Baseline numbers, restarts (and why), monitoring gaps, anything left running or not cleaned up, host limits hit,
and what probes wrote into existing data (endpoints and counts). Logs stay in
the session scratchpad: quote only redacted excerpts here, never secrets.
```
