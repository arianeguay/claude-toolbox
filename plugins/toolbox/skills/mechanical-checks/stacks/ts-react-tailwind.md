# Mechanical checks — TypeScript + React + Tailwind

Run these against `$DIFF` when the diff touches `*.tsx`/`*.ts`. **Extend per repo**; the repo's
`CLAUDE.md`/`AGENTS.md` and linter config win. (Universal checks U1–U3 run from SKILL.md.)

## C1 — Debug statements (auto-fixable)
```bash
git diff "$DIFF" -- '*.ts' '*.tsx' | grep '^+' | grep -nE '\bconsole\.(log|debug)\(|\bdebugger\b'
```
Flag `console.log`/`debugger` added in the diff (keep `console.warn`/`error` unless the repo bans them).

## C2 — Tailwind opacity with leading zero
```bash
git diff "$DIFF" -- '*.tsx' '*.ts' | grep '^+' | grep -oE '[a-z]+-[a-z]+-[0-9]+/0[0-9]'
```
Flag `bg-slate-200/05` → should be `/5`. Run the repo's class linter too (`npm run check` / Biome / prettier-plugin-tailwindcss) for sort + invalid-class detection.

## C3 — Icon-only buttons without an accessible label
```bash
# native + common component buttons containing only an icon, no aria-label/aria-labelledby
git diff "$DIFF" -- '*.tsx' | grep '^+' | grep -E '<(button|Button)\b' | grep -v 'aria-label'
```
Flag buttons whose only child is an icon and that have no `aria-label`/`aria-labelledby`.

## C4 — Relative imports where the repo uses absolute
```bash
git diff "$DIFF" -- '*.ts' '*.tsx' | grep '^+' | grep "from ['\"]\.\./"
```
Flag `../../x` when the repo configures path aliases (check `tsconfig.json` `paths`). Same-folder `./Sibling` is fine. Auto-fixable: rewrite to the alias.

## C5 — i18n key parity (whole-file, generic over detected locales)
Only if the diff touches a locale dir (`public/locales/*`, `locales/*`, `src/i18n/*`) **or** adds `t('…')` calls.
```bash
# Detect locales, then flag keys missing from any locale. Adjust the path/filename to the repo.
node -e '
const fs=require("fs"),p=process.argv[1];
const dirs=fs.existsSync(p)?fs.readdirSync(p):[];
const flat=(o,pre="")=>Object.entries(o).flatMap(([k,v])=>v&&typeof v==="object"?flat(v,pre+k+"."):[pre+k]);
const load=l=>{try{return new Set(flat(JSON.parse(fs.readFileSync(`${p}/${l}/translation.json`))));}catch{return new Set();}};
const locs=dirs; const sets=Object.fromEntries(locs.map(l=>[l,load(l)]));
const all=new Set(locs.flatMap(l=>[...sets[l]]));
let n=0; for(const k of [...all].sort()){const miss=locs.filter(l=>!sets[l].has(k)); if(miss.length){console.log(`MISSING ${k} — absent from: ${miss.join(", ")}`);n++;}}
console.log(n?`\n${n} missing key(s)`:"✅ locale parity OK");
' public/locales
```
Auto-fixable: add the missing keys (flag for translation — never copy English into another locale silently).

## C6 — Orphan i18n keys (only if the diff touches a locale dir)
Keys added/removed in the diff that no `t('key')` call in `src/` still references.
```bash
CHANGED_KEYS=$(git diff "$DIFF" -- 'public/locales/en-US/translation.json' | grep '^[+-]' | grep -v '^[+-][+-][+-]' | grep -oE '"[a-zA-Z_][a-zA-Z0-9_.]*"' | tr -d '"' | sort -u)
for key in $CHANGED_KEYS; do
  grep -rq "t(['\"]${key}['\"])\|t(['\"]${key}\." src/ --include="*.ts" --include="*.tsx" || echo "ORPHAN  $key"
done
```
Slow on a large codebase — run on demand, not by default. Auto-fixable: remove the orphan key from all locales.

## Verify after fixes
```bash
npm run check && npm run type-check    # substitute the repo's actual scripts
```
