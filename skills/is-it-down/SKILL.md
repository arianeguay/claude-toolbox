---
name: is-it-down
description: Check the live status of an external service (GitLab, GitHub, Anthropic, OpenAI, npm, Slack, Cloudflare, Vercel, Docker Hub, Google Cloud, AWS, Notion, Linear, Figma...) via its public status-page API. Use when asked "/is-it-down <service>", "is gitlab down", "is anthropic having issues", "check github status", or when a tool/API call is failing and the cause might be an outage rather than the code.
user-invocable: true
---

# is-it-down

I'm using the is-it-down skill to check live status of external services.

**Core principle:** hit the service's own status-page JSON API (Atlassian Statuspage or equivalent), don't guess from vibes or stale training data.

## Usage

```
/is-it-down gitlab
/is-it-down github anthropic npm
/is-it-down          # no arg → check the core set: gitlab, github, anthropic
```

Multiple services in one call: check all of them, report as one table.

## Known endpoints

Two different vendor platforms are in play — check the schema column before parsing:

| Service | Endpoint | Platform |
|---|---|---|
| gitlab | `https://api.status.io/1.0/status/5b36dc6502d06804c08349f7` | status.io |
| github | `https://www.githubstatus.com/api/v2/status.json` | Statuspage |
| anthropic | `https://status.anthropic.com/api/v2/status.json` (redirects to `status.claude.com` — **use `curl -L`**) | Statuspage |
| openai | `https://status.openai.com/api/v2/status.json` | Statuspage |
| npm | `https://status.npmjs.org/api/v2/status.json` | Statuspage |
| cloudflare | `https://www.cloudflarestatus.com/api/v2/status.json` | Statuspage |
| vercel | `https://www.vercel-status.com/api/v2/status.json` | Statuspage |
| docker / dockerhub | `https://status.docker.com/api/v2/status.json` | Statuspage |
| figma | `https://status.figma.com/api/v2/status.json` | Statuspage |
| notion | `https://status.notion.so/api/v2/status.json` | Statuspage |
| linear | `https://linearstatus.com/api/v2/status.json` | Statuspage |
| slack | `https://slack-status.com/api/v2.0.0/current` | Slack (own schema — see below) |
| google cloud / gcp | `https://status.cloud.google.com/incidents.json` | GCP (own schema — see below) |
| aws | no public JSON status API — use `https://health.aws.amazon.com/health/status` (RSS: `https://status.aws.amazon.com/rss/all.rss`) | — |

This table is a starting point, not exhaustive — for a service not listed, try the generic-guess step below before falling back to a web search. **Always `curl -L`** (follow redirects) — several of these vendors moved/rebranded their status domain and the old one 301s or 404s otherwise (this is exactly what happened with GitLab, historically on Statuspage, now on status.io with a page-scoped API — don't assume the `api/v2/status.json` shape applies to a service just because it "looks like" the others).

## Procedure

### 1. Parse the arg(s)

One or more service names, case-insensitive. No arg → default to `gitlab github anthropic` (the services this user actually depends on day to day — GitLab hosts noether/nabla MRs, GitHub is personal-repo/claude-toolbox, Anthropic is Claude itself).

### 2. Statuspage services (github, anthropic, openai, npm, cloudflare, vercel, docker, figma, notion, linear)

```bash
curl -sL --max-time 5 "https://www.githubstatus.com/api/v2/status.json" | jq -r '.status.indicator, .status.description'
```

`-L` matters — anthropic's `status.anthropic.com` 301s to `status.claude.com`; skip it and you'll silently get a redirect stub instead of JSON.

`indicator` is one of: `none` | `minor` | `major` | `critical`. Map to a plain word:

| indicator | meaning |
|---|---|
| `none` | Operational |
| `minor` | Degraded performance |
| `major` | Partial outage |
| `critical` | Major outage |

If `indicator` is not `none`, also pull the active incident summary for context:

```bash
curl -sL --max-time 5 "https://www.githubstatus.com/api/v2/summary.json" \
  | jq -r '.incidents[] | select(.status != "resolved") | "\(.name) — \(.status)"'
```

### 3. GitLab (status.io schema — different vendor, different shape)

```bash
curl -s --max-time 5 "https://api.status.io/1.0/status/5b36dc6502d06804c08349f7" \
  | jq -r '.result.status_overall.status, (.result.incidents // [] | length)'
```
First line is a plain-English status (`"Operational"`, `"Degraded Performance"`, `"Partial Outage"`, `"Major Outage"`) — no indicator-code mapping needed. Second line is the open-incident count; if nonzero, `.result.incidents[].name` for the summary.

### 4. Slack (own schema)

```bash
curl -s --max-time 5 "https://slack-status.com/api/v2.0.0/current" | jq -r '.status'
```
`"ok"` → Operational. `"active"` → check `.active_incidents[].title` for the summary.

### 5. Google Cloud (own schema)

```bash
curl -s --max-time 5 "https://status.cloud.google.com/incidents.json" | jq -r 'map(select(.end == null)) | length'
```
`0` → Operational. `>0` → list the open incidents' `.external_desc`.

### 6. Unknown service — generic guess, then fall back

Try the two most common Statuspage URL shapes before giving up:

```bash
for url in "https://status.$SERVICE.com/api/v2/status.json" "https://status.$SERVICE.io/api/v2/status.json" "https://$SERVICE-status.com/api/v2/status.json"; do
  curl -sL --max-time 5 "$url" | jq -e '.status.indicator' >/dev/null 2>&1 && echo "$url" && break
done
```

If none resolve, say so plainly and offer a WebSearch for "`$SERVICE` status page" instead of fabricating a URL — never guess a domain and present it as authoritative.

### 7. Report

One compact table, most-relevant service first if the user named one explicitly:

```
Service      Status                 Notes
gitlab       ✅ Operational          —
github       ✅ Operational          —
anthropic    ⚠️  Degraded performance  Elevated error rates on API — since 14:02 UTC
```

Keep it to the table — no restating the procedure, no per-service prose unless there's an active incident worth a one-line summary.

## Notes

- 5s `--max-time` on every curl — a hung status page shouldn't hang the check itself (that's its own signal: unreachable ≠ confirmed down, report as "couldn't reach status page" rather than "down").
- These are the **provider's own** status pages — self-reported, can lag a real incident by a few minutes. Good enough to rule out "is it me or them" before debugging further.
- Don't cache/remember results across sessions — status changes minute to minute, always re-check live.
