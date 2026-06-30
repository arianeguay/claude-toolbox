#!/usr/bin/env python3
"""Post inline comments / code-suggestions on a GitLab MR — and locate anchorable lines.

Why this exists: `glab api -f "position[new_line]=N"` does NOT serialize bracket
notation into nested JSON, so GitLab silently ignores the position and creates a
*general* note (HTTP 201, position: null, no error). This posts the proper nested
`position` object via the REST API directly, and verifies the position stuck.

Token: $GITLAB_ACCESS_TOKEN, else `glab auth status -t`.

Usage:
  # 1. Find where a line lives in the diff (added vs context vs absent):
  mr_comment.py locate --project gray-suite/noether --mr 1734 \
      --path CLAUDE.md --match "SCSS modules"

  # 2. Post (added line -> --new-line only; context line -> add --old-line):
  mr_comment.py post --project gray-suite/noether --mr 1734 \
      --path CLAUDE.md --new-line 147 --body-file note.md
"""
import argparse, json, os, re, subprocess, sys, urllib.parse, urllib.request

API = "https://gitlab.com/api/v4"


def token():
    t = os.environ.get("GITLAB_ACCESS_TOKEN")
    if t:
        return t
    out = subprocess.run(["glab", "auth", "status", "-t"],
                         capture_output=True, text=True).stderr or ""
    m = re.search(r"Token:\s*(\S+)", out)
    if not m:
        sys.exit("No token: set GITLAB_ACCESS_TOKEN or run `glab auth login`.")
    return m.group(1)


def call(method, path, tok, body=None):
    url = f"{API}/{path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"PRIVATE-TOKEN": tok,
                                          "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code}: {e.read().decode()[:500]}")


def enc(project):
    return urllib.parse.quote(project, safe="")


def locate(args, tok):
    """Classify a target line in the MR diff: added / context / absent."""
    iid, p = args.mr, enc(args.project)
    # access_raw_diffs=true: otherwise GitLab collapses large-file diffs to empty text.
    ch = call("GET", f"projects/{p}/merge_requests/{iid}/changes?access_raw_diffs=true", tok)
    hits = []
    for c in ch.get("changes", []):
        if c["new_path"] != args.path:
            continue
        old = new = 0
        for line in c["diff"].splitlines():
            m = re.match(r"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@", line)
            if m:
                old, new = int(m.group(1)), int(m.group(2))
                continue
            if line.startswith("+") and not line.startswith("+++"):
                if args.match in line[1:]:
                    hits.append(("ADDED", None, new, line[1:].rstrip()))
                new += 1
            elif line.startswith("-") and not line.startswith("---"):
                old += 1
            else:
                if args.match in line[1:]:
                    hits.append(("CONTEXT", old, new, line[1:].rstrip()))
                old += 1
                new += 1
    if not hits:
        print(f"ABSENT — '{args.match}' is not in the diff for {args.path}.\n"
              "It's likely in an unchanged island: you CANNOT post a suggestion "
              "there. Anchor a note on the nearest ADDED line instead.")
        return
    for typ, ol, nl, text in hits:
        flag = "--new-line %d" % nl if typ == "ADDED" else "--new-line %d --old-line %d" % (nl, ol)
        print(f"{typ}  {flag}   | {text[:70]}")


def post(args, tok):
    iid, p = args.mr, enc(args.project)
    mr = call("GET", f"projects/{p}/merge_requests/{iid}", tok)
    d = mr["diff_refs"]
    body = open(args.body_file).read() if args.body_file else args.body
    if not body:
        sys.exit("Provide --body-file or --body.")
    pos = {"base_sha": d["base_sha"], "start_sha": d["start_sha"],
           "head_sha": d["head_sha"], "position_type": "text",
           "new_path": args.path, "old_path": args.path,
           "new_line": args.new_line}
    if args.old_line is not None:
        pos["old_line"] = args.old_line
    res = call("POST", f"projects/{p}/merge_requests/{iid}/discussions", tok,
               {"body": body, "position": pos})
    note = (res.get("notes") or [None])[0]
    if note and note.get("position"):
        print(f"OK inline -> {note['position']['new_path']}:{note['position']['new_line']}")
    else:
        sys.exit("POSTED BUT NO POSITION — landed as a general note. Re-check the "
                 "line is in the diff (run `locate`); context lines need --old-line.")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("locate", "post"):
        s = sub.add_parser(name)
        s.add_argument("--project", required=True, help="owner/repo")
        s.add_argument("--mr", type=int, required=True)
        s.add_argument("--path", required=True)
    sp = sub.choices["locate"]
    sp.add_argument("--match", required=True, help="substring to find in the diff")
    pp = sub.choices["post"]
    pp.add_argument("--new-line", type=int, required=True)
    pp.add_argument("--old-line", type=int, default=None,
                    help="required only for an unchanged CONTEXT line")
    pp.add_argument("--body-file")
    pp.add_argument("--body")
    args = ap.parse_args()
    tok = token()
    (locate if args.cmd == "locate" else post)(args, tok)


if __name__ == "__main__":
    main()
