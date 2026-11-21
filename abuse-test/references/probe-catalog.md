# Probe catalog

Pick the classes that fit each target. Not every probe applies to every
endpoint: a GET with no parameters doesn't need a unicode fuzz.

## 1. Malformed and extreme input

Apply per field (query param, JSON key, form field, header, path segment,
file name, file content).

| Probe | Values to try |
|---|---|
| Missing / empty | field absent, `""`, `null`, `[]`, `{}`, whitespace only |
| Wrong type | string for number, number for string, array for scalar, object for array, `true` for string |
| Numeric edges | `0`, `-1`, `-0`, `1e308`, `NaN`, `Infinity`, `2^31`, `2^53+1`, `0.1+0.2`, `"1,5"` vs `"1.5"`, leading zeros |
| Length | 1 char, max-1/max/max+1 of any documented limit, 10 k, 1 MB string |
| Unicode | emoji `\U0001F9E8`, RTL override `\u202E`, zero-width space `\u200B`, combining `e\u0301`, NUL `\u0000`, lone surrogate `\ud800`, mixed scripts, very long grapheme clusters (write these as escapes in probes, not literal characters) |
| Injection-shaped (to test handling, not exploit) | `'";--`, `<script>alert(1)</script>`, `{{7*7}}`, `${7*7}`, `../../etc/passwd`, `%00`, CRLF `\r\nX-Injected: 1` |
| Dates/times | `2024-02-30`, `0000-00-00`, year 9999, `1970-01-01T00:00:00Z`, DST gaps, timezone `+14:00`, epoch ms vs s |
| Structure | invalid JSON, trailing comma, duplicate keys, 1000-deep nesting, wrong `Content-Type`, body on GET, unknown extra fields |
| Files | 0 bytes, wrong extension vs content, `.jpg` that's really text, huge filename, filename with `/`, `..`, unicode, many files at once |
| Encoding | invalid UTF-8 bytes, BOM, double URL-encoding, `+` vs `%20` |

Frontend versions: paste the above into inputs, paste 1 MB of text, type into
number fields, drop wrong files on file inputs, edit `value`/`max` limits away
via devtools-style DOM changes and submit, change URL params by hand.

## 2. Concurrency and timing

| Probe | How |
|---|---|
| Double submit | Same write request N times within 100 ms (`xargs -P`, `asyncio`, `curl --parallel`). Check for duplicate records/side effects. |
| Check-then-act race | Parallel requests that each should pass a uniqueness/stock/balance check only once. |
| Read-modify-write | Parallel increments/updates of the same record; compare final value to expected. |
| Out-of-order | Send update before create, delete then update, two edits with stale versions/ETags. |
| Retry storms | Repeat a request after a client-side timeout while the first is still running. |
| Slow client | Send headers/body byte-by-byte (slowloris-style) on N connections, within caps. Does it block other users? |
| Abandoned requests | Close the connection mid-upload / mid-response, or let the client time out. Are temp files (including deleted-but-open ones) and DB transactions cleaned up? Does the server-side job stop, or keep running and hold the worker? |
| WebSocket | Rapid connect/disconnect, messages before handshake completes, flood within caps, messages after close. |

Frontend versions: double/triple-click submit buttons, press Enter while a
request is in flight, back/forward during a save, refresh mid-submit, open
the same form in two tabs and save both, navigate away during an
optimistic update, rapid filter/search typing (stale responses arriving out
of order), go offline mid-action (`context.setOffline(true)` in Playwright).

## 3. Resource exhaustion (bounded)

Always ramp through the steps in the SKILL.md intensity table and record
memory/CPU/response time at each step against the baseline.

| Probe | What to look for |
|---|---|
| Large body | Is there a size limit? Does memory spike proportionally (whole body buffered)? |
| Large upload | Disk usage, temp files left behind, timeouts. |
| Huge arrays / many items | Request with 100 k items; page size `?limit=1000000`; deep pagination `?page=999999`. |
| Expensive queries | Wildcard/regex search `.*.*.*`, sort on unindexed fields, filters that defeat indexes. |
| Algorithmic cost | Small, valid inputs whose processing grows faster than their size: many CSS selectors, headings, nested elements, regex-heavy fields, many archive members. Ramp 100 → 1 k → 10 k elements, time each step, and time a tiny second request meanwhile to see who else is blocked. |
| Accumulation | Repeat an in-cap request 2 → 5 → 20 times (abandoned uploads, stored jobs) and measure what stays after each finishes. Only with the app inside a memory limit. |
| Decompression | Small gzip body that expands hugely (`Content-Encoding: gzip`), within the payload cap after expansion. |
| Connection hoarding | Hold N idle keep-alive or WebSocket connections; do new users still get served? |
| Unbounded growth | Repeat a normal action many times (sessions, cache keys, log lines, queued jobs); does memory/disk keep climbing? |

Frontend versions: render a list with 10 k+ items, open the same heavy page
many times in one session and watch JS heap (`performance.memory` or
Playwright metrics), leave a page with live updates open and watch memory grow.

## Probe file skeleton

Every probe starts with the target guard: it only runs against the base URL(s)
approved in the plan, written into the probe when you generate it. Someone
re-running it elsewhere sets `ABUSE_ALLOW` to their own checked base URL.
Tokens come from the environment, never from the file. Count only what this
run created (a unique marker) and print expected vs actual.

```bash
#!/usr/bin/env bash
# Finding: F03 double submit on POST /api/orders creates duplicate orders
# Expect: 1 order (the rest 409). Got: 5 orders.
set -euo pipefail
BASE="${1:?usage: $0 <base-url>}"
ALLOW="${ABUSE_ALLOW:-http://127.0.0.1:3000}"   # approved base URL(s), space-separated
case " $ALLOW " in *" $BASE "*) ;; *) echo "refusing $BASE (not in: $ALLOW)" >&2; exit 20 ;; esac
TOKEN="${APP_TOKEN:?set APP_TOKEN to the throwaway token}"

RUN="abuse-$(date +%s)-$$"
codes=$(mktemp)
for i in 1 2 3 4 5; do
  curl -s -o /dev/null -w '%{http_code}\n' -X POST "$BASE/api/orders" \
    -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
    -d "{\"sku\":\"A1\",\"qty\":1,\"note\":\"$RUN\"}" >>"$codes" &
done
wait
echo "status codes: $(sort "$codes" | uniq -c | tr '\n' ' ')"
got=$(curl -sf -H "Authorization: Bearer $TOKEN" "$BASE/api/orders?note=$RUN" | grep -o "\"note\":\"$RUN\"" | wc -l)
echo "expected 1 order, got $got"
rm -f "$codes"
[ "$got" -le 1 ]
```
