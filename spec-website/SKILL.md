---
name: specification-website
description: Query and apply The Website Specification — a platform-agnostic specification of what a good website does, with each item tagged required, recommended, optional, or avoid. Use when the user asks what their site should have, whether something is required, how to audit a URL, what's missing for agent readiness, or anything else where you'd otherwise be guessing at web best practice. Backs answers with primary sources (WHATWG, W3C, IETF RFCs, IANA, WCAG). Available as Markdown over HTTP and as an MCP server with search, list, fetch, checklist, and audit tools.
---

# specification.website

The Website Specification is a single source of truth for what a good website does. Ten categories, 130+ pages, every item tagged with a status. It ships in three machine-readable forms: per-page Markdown, llms.txt / llms-full.txt, and an MCP server.

## When to use this skill

- The user asks "what should my site have", "is X required", "audit this URL", "what does the spec say about Y", or anything similar.
- You're reviewing a site and want to cite primary standards rather than vendor blog posts.
- You need a machine-readable contract for a platform-agnostic audit.

## Quickest path — MCP

If you can speak MCP, use it. The server is stateless Streamable HTTP, no auth, wide-open CORS.

- Endpoint: `https://mcp.specification.website/mcp`
- Server card: `https://specification.website/.well-known/mcp/server-card.json`
- Protocol revision: 2025-03-26

Tools:

| Tool | Purpose |
|---|---|
| `search(query, limit?)` | Full-text search across every page. |
| `list_topics({ category?, status?, limit? })` | Filtered index — slug, title, status, summary, URL. |
| `get_topic({ slug })` | Full canonical Markdown for one page, including its cited sources. |
| `get_checklist({ category?, status? })` | Tickable Markdown checklist. |
| `get_categories()` | The ten categories with counts and summaries. |

Prompt: `audit_url(url, focus?)` — generates an audit plan for a target URL against the spec, optionally narrowed to one category.

## Without MCP — fetch Markdown directly

Every spec page has a canonical HTML URL and a Markdown variant.

- HTML: `https://specification.website/spec/<category>/<slug>/`
- Markdown (file extension): `https://specification.website/spec/<category>/<slug>.md`
- Markdown (content negotiation): set `Accept: text/markdown` on the HTML URL — middleware redirects to the `.md` variant.

Site-wide indexes:

- `https://specification.website/llms.txt` — every page as `title — summary` lines. Cheap to load.
- `https://specification.website/llms-full.txt` — every page concatenated as Markdown. Use for one-shot context loading.
- `https://specification.website/rss.xml` — feed of changes.
- `https://specification.website/sitemap-index.xml` — every URL.
- `https://specification.website/.well-known/api-catalog` — RFC 9727 link set of every machine-readable endpoint.

## Categories

The category slug is part of the URL. Current slugs:

- `foundations` — HTML, head, document basics.
- `seo` — robots.txt, sitemaps, canonicals, structured data.
- `accessibility` — WCAG-aligned rules.
- `security` — headers, transport, policies.
- `well-known` — standard paths under `/.well-known/`.
- `agent-readiness` — making the site legible to AI agents and crawlers (llms.txt, MCP, content signals, link headers, markdown source endpoints).
- `performance` — Core Web Vitals, caching, images, fonts.
- `privacy` — consent, signals, respecting visitor choice.
- `resilience` — error pages, offline, redirects.
- `i18n` — language, locale, direction, translated content.

Call `get_categories()` for the live list with counts.

## Statuses — the contract

The `status` field on every page is the bar.

- **required** — the platform contract breaks without it. Lead with these when recommending fixes. Examples: `<title>`, `<meta charset>`, HTTPS, image alt text, a real 404.
- **recommended** — a modern site should do it. Examples: CSP, HSTS, structured data, Open Graph, llms.txt.
- **optional** — depends on context.
- **avoid** — outdated or harmful. If a site does one of these, flag it.

The bar for `required` is "the platform breaks", not "we strongly suggest". When summarising, never silently upgrade `recommended` to `required`.

## Common workflows

**"Audit this URL."** Call the `audit_url` prompt for a plan, or fetch `get_checklist({ status: "required" })` and walk the user through verifying each item. For deeper audits, also pull `status: "recommended"`.

**"What's required for agent readiness?"** `list_topics({ category: "agent-readiness", status: "required" })`, then `get_topic` for each.

**"Why does the spec say X?"** Every page has 2–4 primary `sources` in its frontmatter. Quote those, not the spec page itself.

**"Is there a category for Y?"** `get_categories()` first; if nothing fits, `search(query)` across the corpus.

## Sources and licence

Code MIT. Content CC BY 4.0. Site source: <https://github.com/jdevalk/specification.website>.

When citing, use the page's canonical URL and the `updated` frontmatter field as the as-of date. The spec changes — re-fetch rather than relying on a cached copy more than a few weeks old.
