---
name: am-i-stuck
description: Check volontaire en cours de building pour détecter si l'utilisatrice est dans le tunnel ou a perdu sa position sur le hill chart. Utiliser quand elle demande "am I stuck", "je suis où là", "hill check", "je tourne en rond", "ça fait longtemps que je suis sur ça". Aussi appelable quand elle dit "fak je pense que je suis dans le tunnel". Produit un diagnostic rapide et une recommandation d'action concrète (continuer, downscope, pause, reshape, demander de l'aide). 5 min max. NE PAS utiliser en Desktop (c'est un outil de building).
---

# Am I Stuck — Détection in-flight

Check **volontaire** en cours de building. Pas un watchdog automatique qui interrompt le flow — un outil que l'utilisatrice invoque quand elle sent qu'elle tourne en rond ou qu'elle n'est plus sûre d'où elle en est.

**Principe** : l'hyperfocus AuDHD rend très difficile de distinguer "je cherche encore" vs "j'exécute". Ce skill externalise cette distinction avec des questions concrètes et produit une recommandation d'action.

**Scope** : c'est un outil de **diagnostic + action**, pas de "recadrage émotionnel". Si l'utilisatrice est en détresse, ce n'est pas ce skill qui aide — c'est une pause.

## Quand utiliser

Activation explicite via :
- "am I stuck"
- "hill check"
- "je suis où là"
- "je tourne en rond"
- "ça fait longtemps que je suis sur ça"
- "fak je pense que je suis dans le tunnel"

Également approprié quand l'utilisatrice fait un commentaire de frustration ("pourquoi ça marche pas", "j'ai tout essayé") — proposer alors :
> "Check rapide avec `am-i-stuck` avant de continuer ? Ça prend 3-5 min."

Ne **pas** se déclencher automatiquement sur un timer. L'utilisatrice invoque quand elle en a besoin.

## Flow

### Étape 1 — Collecter la position (4 questions)

Poser **exactement 4 questions** via `ask_user_input_v0`. Pas plus. La valeur du skill c'est la brièveté.

**Question 1 — Hill chart**

> "Tu es où sur le hill chart pour ce ticket ?"
> Options :
> - "Uphill — je cherche encore la solution"
> - "Juste en haut de la colline — j'ai une idée mais pas validée"
> - "Downhill — je sais quoi faire, j'exécute"
> - "Je sais plus où je suis"

**Question 2 — Temps investi**

> "Depuis combien de temps t'es sur cette session de travail ?"
> Options :
> - "< 1h"
> - "1-2h"
> - "2-4h"
> - "Plus de 4h cumulées aujourd'hui"

**Question 3 — Signal interne**

> "Comment tu te sens par rapport au progrès ?"
> Options :
> - "Je progresse, c'est juste long"
> - "Je tourne en rond, j'essaie la même chose sous différents angles"
> - "Je saute d'un fil à l'autre, chaque fil semble prometteur"
> - "Je suis à court d'idées, je ne sais plus quoi essayer"

**Question 4 — Scope check (anti hyperfocus drift)**

> "Ce sur quoi tu travailles **maintenant**, c'est exactement ce que le ticket demande, ou ça a élargi ?"
> Options :
> - "Pareil que le ticket, scope intact"
> - "J'ai ajouté un ou deux trucs adjacents qui me semblaient pertinents"
> - "Je suis dans un sous-problème que j'ai découvert en chemin"
> - "Honnêtement je sais plus si c'est dans le scope original"

Cette question externalise la dérive de scope que l'hyperfocus AuDHD rend invisible. Une réponse autre que la première est un signal — pas forcément un problème, mais à diagnostiquer.

### Étape 2 — Diagnostic

Croiser les 3 réponses pour produire un diagnostic. Voici la matrice des patterns principaux :

**Pattern 1 — Progrès normal**
- Hill: Uphill ou Downhill
- Temps: < 2h
- Signal: "Je progresse"
→ Diagnostic : "Tu n'es pas stuck. Continue."

**Pattern 2 — Uphill prolongé (classique hyperfocus)**
- Hill: Uphill
- Temps: > 2h
- Signal: "Je tourne en rond" ou "Je saute d'un fil à l'autre"
→ Diagnostic : "Tu es dans le tunnel uphill. Signal classique : tu crois chercher la solution, tu explores des impasses en cercle. Coût d'opportunité élevé."

**Pattern 3 — Faux downhill**
- Hill: Downhill
- Temps: > 2h
- Signal: "Je tourne en rond"
→ Diagnostic : "Tu te penses downhill mais tu tournes en rond. Signal que tu étais en fait encore uphill — la solution que tu pensais avoir ne tient pas. Retour en vrai uphill nécessaire."

**Pattern 4 — Désorientation**
- Hill: "Je sais plus où je suis"
- Temps: peu importe
- Signal: peu importe
→ Diagnostic : "Tu as perdu le fil du ticket. Besoin de re-ancrer dans le scope avant d'avancer."

**Pattern 5 — Épuisement**
- Hill: peu importe
- Temps: > 4h
- Signal: "À court d'idées" ou "Je saute d'un fil à l'autre"
→ Diagnostic : "Fatigue cognitive probable. Les heuristiques internes ne répondent plus. Pause non-négociable avant décision."

**Pattern 6 — Blocage externe**
- Hill: Uphill
- Temps: > 1h
- Signal: "À court d'idées"
→ Diagnostic : "Possible blocage par manque d'info externe. Une question à une personne ou une doc à lire pourrait débloquer plus vite que continuer seul."

**Pattern 7 — Scope creep silencieux (hyperfocus drift)**
- Scope (Q4): "ajouté trucs adjacents", "sous-problème découvert", ou "sais plus si dans le scope"
- Hill et Temps : peu importe
→ Diagnostic : "Tu travailles sur quelque chose qui a glissé hors du ticket. C'est le pattern hyperfocus classique : chaque branche semble pertinente, mais la somme dépasse le scope. Coût : le ticket original ne ship pas pendant que tu construis l'adjacence."

Ce pattern domine les autres quand il est détecté — un faux-downhill ou un uphill prolongé sur du code hors-scope est une dérive, pas un blocage.

### Étape 3 — Recommandation d'action (1 seule, concrète)

Proposer **une seule** action concrète adaptée au pattern :

**Pattern 1 — Progrès normal**
> "Continue. Pas besoin d'intervention. Re-check dans ~1h si tu veux."

**Pattern 2 — Uphill prolongé**
> "Recommandation : downscope avant de continuer.
>
> Concrètement : prends 2 min pour écrire ce que tu cherches à faire actuellement. Si c'est plus ambitieux que le scope du bundle initial, coupe la partie ambitieuse maintenant. Si c'est dans le scope, alors le rabbit hole est réel et mérite soit un spike de 30 min max, soit un retour en Desktop pour reshape."

**Pattern 3 — Faux downhill**
> "Recommandation : retour en uphill explicite.
>
> Concrètement : laisse tomber la solution actuelle qui ne tient pas. Reviens en mode exploration (brainstorm ou sketch) avant de re-écrire du code. Te forcer à re-écrire va juste produire plus de code qui ne tient pas."

**Pattern 4 — Désorientation**
> "Recommandation : re-lire le bundle shaping.
>
> Concrètement : ouvre le bundle original (ou le ticket Linear si pas de bundle). Relis le 'Ce qu'on ship' et le 'Premier pas'. Identifie un pas concret qui est dans le scope. Fais-le. Si tu ne peux pas identifier un pas concret, c'est un signal pour `ticket-shape` en mode 'bloquée' (retour Desktop)."

**Pattern 5 — Épuisement**
> "Recommandation : pause non-négociable.
>
> Concrètement : ferme Claude Code. Lève-toi, bois de l'eau, sors de l'écran 20 min minimum. Aucune décision technique ni de scope d'ici là. Si à ton retour tu es toujours épuisée, la session est finie pour aujourd'hui — le ticket attendra."

**Pattern 6 — Blocage externe**
> "Recommandation : identifier ce qui débloque.
>
> Concrètement : pose-toi la question 'qu'est-ce que j'aurais besoin de savoir pour avancer ?' En 2 min, écris une phrase précise. Si la réponse est dans la codebase, va la chercher. Si la réponse est chez quelqu'un, envoie le message maintenant (même Slack async) et commence autre chose pendant que tu attends."

**Pattern 7 — Scope creep silencieux**
> "Recommandation : couper le scope hors-ticket maintenant.
>
> Concrètement : nomme en une phrase ce qui a été ajouté ou découvert hors du scope original. Trois options : (a) c'est pas critique → drop, garde les changements pour plus tard ou jette, (b) c'est un vrai sous-ticket → stash le code, ouvre un ticket Linear via `linear-issue-creator`, retourne au scope initial, (c) c'est en fait dans le scope mais pas reconnu au shaping → retour Desktop pour reshape via `ticket-shape`. Choisir maintenant, pas dans 30 min."

### Étape 4 — Proposer le follow-up

Après la recommandation, demander :

> "Tu veux que je t'aide à exécuter cette action, ou tu prends ça de là ?"
> - "Aide-moi avec [l'action]"
> - "Je prends de là"
> - "En fait je veux retourner en Desktop pour reshape via `ticket-shape`"

Si "aide-moi" : exécuter l'action avec l'utilisatrice (downscope, relecture du bundle, rédaction du message async, etc.).
Si "je prends de là" : laisser faire, ne pas re-checker sans invocation.
Si "retour Desktop" : nommer le bridge : "OK, ouvre Claude Desktop et dis `je suis bloquée sur GRA-XXXX`, ça va déclencher le mode bloquée de `ticket-shape`."

### Étape 5 — Noter le pattern pour retrospect

Si l'utilisatrice a rencontré un pattern 2, 3, 5 ou 6 sur ce ticket, noter mentalement pour que, quand `ticket-retrospect` sera fait après le ship, cette info soit disponible. Format :

```
Note pour retrospect de GRA-XXXX:
- Session stuck à [timestamp/durée]
- Pattern: [nom du pattern]
- Action prise: [ce qu'on a fait]
- Résolu: [oui/non/à vérifier après]
```

Cette note alimente le retrospect et révèle les patterns récurrents.

## Règles strictes

**Durée max : 5 min.** Si le diagnostic prend plus de temps, c'est qu'il manque de l'info claire — clôturer avec "pas de diagnostic clair, retour en Desktop pour reshape via `ticket-shape`".

**Une seule recommandation.** Pas de menu de 3 options d'action. AuDHD + dans le tunnel = décision minimale requise. Un choix, clair.

**Pas de jugement.** Ne jamais dire "tu aurais dû t'arrêter plus tôt" ou "tu devrais connaître ce pattern". Le fait qu'elle invoque le skill est déjà la bonne action. Point.

**Ne pas forcer une action.** Si elle veut ignorer la recommandation et continuer, c'est son droit. Noter qu'on a fait le check et passer.

## Ne pas faire

- Ne pas se déclencher automatiquement sur un timer
- Ne pas poser > 3 questions
- Ne pas proposer plusieurs actions
- Ne pas juger la situation
- Ne pas moraliser sur l'hygiène de travail
- Ne pas faire de discours sur la fatigue cognitive
- Ne pas tenter de reshape depuis Claude Code — toujours rediriger vers Desktop si reshape nécessaire
- Ne pas oublier de noter le pattern pour retrospect

## Format de sortie

- Français québécois, registre oral OK
- Pas d'emojis
- Diagnostic en 1-2 phrases max
- Recommandation en format "Recommandation: X. Concrètement: [étapes précises]"
- Ne pas commencer une phrase par son prénom
- Pas de pep talk, pas de "tu vas y arriver", pas de "reste forte"
- Factuel et court
