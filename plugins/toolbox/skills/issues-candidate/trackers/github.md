# Tracker: GitHub Issues (`gh`)

GitHub has no native priority/estimate fields — they live as **labels** (`priority: high`) or as **Project v2 custom fields**. Never silently drop them: pick the repo's existing mechanism, or state which one you used.

```bash
gh auth status || echo "STOP — gh auth login"
gh label list --limit 100          # only existing labels can be applied
gh project list --owner "$(gh repo view --json owner -q .owner.login)" 2>/dev/null
```

## Dedup search (Step 3)

```bash
gh issue list --state all --search "<3-5 distinctive title words>" --limit 20 \
  --json number,title,state,url
```
A hit that isn't `CLOSED` → drop the candidate, cite `#<number>`. One search per candidate, on title words rather than your phrasing of the fix.

## Create (Step 6A)

```bash
gh issue create \
  --title "<imperative title>" \
  --body-file <(cat <<'EOF'
**Symptom** — <what is observably wrong / missing>

**Where** — `path/to/file.py:212` (or: surfaced while doing <task>)

**Why not in this PR** — <one line>

**What a fix involves** — <2-4 lines: approach + what proves it>

Blocked by #<n>   <!-- ordering; omit if none -->
EOF
) \
  --label bug --label "priority: high" \
  --project "<project>"          # only if the repo uses Projects for estimate/priority
```

- Labels must already exist — `gh label create` first, or fall back to a label the repo has.
- No `blockedBy` primitive: state it as `Blocked by #<n>` in the body **and**, if the repo uses Projects v2, set the dependency field there.
- Estimate: a `size: S/M/L` label or a Project v2 number field, whichever the repo already uses.

Report the returned issue URL for Step 8.
