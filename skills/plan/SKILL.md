---
name: plan
description: Produire un plan d'implémentation ancré dans le vrai code — le pont manquant entre le shaping (décisions/rationales/rabbit holes) et le build. Utiliser en Claude Code juste avant de coder, quand l'utilisatrice dit "fais-moi un plan", "plan pour GRA-XXXX", "on planifie avant de coder", "avant de commencer", ou après `ticket-unbundle` quand le contexte de shaping est prêt mais qu'il manque un plan concret. Consomme le contexte déjà unbundlé s'il est présent (chemin principal), sinon prend un ticket GRA-XXXX ou une description brute et lit le code elle-même (fallback pour les tickets TRIVIAL qui skippent le shaping). Sort une liste ordonnée de changements avec les fichiers touchés, persistée dans `.plans/GRA-XXXX.md`. NE PAS utiliser pour shaper (ça, c'est `ticket-shape` en Desktop) ni pour décider du scope — ici on décide le COMMENT, pas le QUOI.
---

# Plan — Pont Shaping → Build

Dernier maillon avant de coder. Le shaping décide **quoi** ship et dans **quel ordre** ; ce skill décide **comment**, ancré dans le vrai code.

**Principe** : le bundle de shaping donne les décisions et leurs rationales, mais pas un plan d'implémentation validé contre la codebase. Ce skill comble ce trou — il lit le code réel pour confirmer ce qui existe (réutiliser vs construire), où le changement s'insère, quel pattern suivre, puis sort une liste ordonnée de changements. C'est le "comment" concret que brainstorm/plan génériques ne pouvaient pas ancrer.

**Ce que ce skill n'est PAS** : pas des phases lourdes avec critère de vérif par étape façon superpowers. Une liste ordonnée, chaque item nomme les fichiers touchés. Cohérent avec `smallest-footprint` : le plan le plus léger qui laisse coder sans re-deviner.

## Détection du chemin d'entrée (Étape 0)

Auto-détecter, ne pas demander à l'utilisatrice de choisir.

**Option A — contexte de shaping déjà présent (chemin principal)** : les décisions, rationales et rabbit holes du ticket sont déjà dans la conversation (`ticket-unbundle` a tourné cette session, ou l'utilisatrice a collé/résumé le shaping). Les réutiliser tels quels — ne pas re-demander, ne pas relire le bundle sur disque si le contexte est déjà là.

Si rien n'est en contexte, chercher un bundle persisté avant de tomber en fallback. Extraire le ticket ID :
```bash
TICKET_ID=$(git branch --show-current | grep -oiE 'GRA-[0-9]+' | tr '[:lower:]' '[:upper:]')
BUNDLE="/Users/arianeguay/dev/src/claude-shaping/${TICKET_ID}.md"
[ -f "$BUNDLE" ] && cat "$BUNDLE"
```
Fichier trouvé → l'ingérer comme contexte Option A.

**Fallback — pas de contexte de shaping** : couvre les tickets TRIVIAL qui skippent le shaping. Prendre l'entrée disponible :
- Un GRA-XXXX (branche ou message) → lire le ticket Linear via MCP pour le titre + la description.
- Une description brute collée → travailler à partir de ça.

Le fallback lit le code lui-même sans bénéficier des rationales de shaping. Ne pas re-shaper (pas de découpage de scope, pas de rabbit holes) — juste planifier le comment du travail tel que décrit.

Nommer le chemin retenu en une ligne : `Chemin: Option A (contexte shaping)` ou `Chemin: fallback (ticket TRIVIAL)`.

## Ancrer le plan dans le code (Étape 1)

C'est la valeur du skill — ne pas la sauter. Avant d'écrire une seule ligne du plan, lire le code réel pour valider chaque hypothèse d'implémentation :

- **Réutiliser vs construire** : le composant/util/hook/endpoint dont on a besoin existe-t-il déjà ? Grep avant de supposer qu'il faut le créer (`DisplayMap`, un util `.utils.ts`, un selector, un endpoint nabla). Réutiliser bat réinventer — `mr-uniformity-check` le flaggerait sinon.
- **Point d'insertion** : où le changement se branche-t-il ? Lire le fichier cible, repérer la fonction/composant exact et le pattern voisin à suivre.
- **Couplage implicite** : y a-t-il un jumeau à garder en phase (deux fonctions synchronisées, i18n 3 locales, un selector qui doit re-projeter dans le scope) ?
- **Contredit le shaping ?** : si le code contredit une décision du bundle (un pattern assumé n'existe pas, un endpoint manque), le nommer explicitement — c'est le seul cas où on remonte au shaping. Ne pas patcher silencieusement.

Chaque item du plan doit tracer vers du code lu, pas deviné. Si une hypothèse n'a pas pu être vérifiée, la marquer `(non vérifié)` plutôt que de l'affirmer.

## Produire le plan (Étape 2)

Liste ordonnée. Chaque item : ce qui change, le(s) fichier(s), et la note réutilise-vs-nouveau quand c'est pertinent. Léger.

```markdown
# Plan — GRA-XXXX : [titre]

Chemin: [Option A (contexte shaping) | fallback (TRIVIAL)]
Scope: [une phrase — ce qu'on ship]

## Changements

1. [Action concrète] — `chemin/fichier.tsx`
   [1 clause de contexte si non évident : réutilise `X`, suit le pattern de `Y`, ou nouveau]
2. [Action] — `chemin/autre.ts`
3. ...

## Notes d'ancrage
- Réutilisé: [utils/composants existants trouvés]
- Nouveau: [ce qui n'existe pas et doit être créé]
- Non vérifié / hypothèses: [ou "aucune"]
- i18n: [clés à ajouter dans les 3 locales, ou "aucune"]
```

Pas de critère de vérif par étape, pas de phases nommées. L'ordre des items EST le fil du build. Grouper les changements comme ils seront commités (un item ≈ un commit logique quand ça tombe bien).

Rester dans le scope shapé. Ne pas ajouter d'items "tant qu'on y est" — chaque ligne trace vers ce qui a été demandé.

## Persister (Étape 3)

Écrire le plan sur disque à la racine du worktree :
```bash
mkdir -p .plans
# écrire dans .plans/${TICKET_ID}.md
```
Si pas de ticket ID (fallback sur description brute), utiliser un slug court : `.plans/<slug>.md`.

Survit à la session, retrouvable par `ticket-retrospect` pour comparer plan vs réalité.

## Passer au build (Étape 4)

Le plan est le guide de build. Confirmer visuellement à l'utilisatrice le plan produit, puis l'exécuter de haut en bas : coder chaque item, commit par changement logique (voir `/commit`), lint + type-check + tests en cours de route (autonomie — ne pas demander la permission).

Si un item se révèle faux en cours de build (le code ne matche pas le plan), corriger le plan en même temps que le code — ne pas laisser `.plans/GRA-XXXX.md` diverger de la réalité.
