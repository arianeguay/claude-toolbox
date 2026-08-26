---
name: am-i-stuck
description: Deliberate in-flight check to detect whether you're in the tunnel or have lost your position on the hill chart. Use when the user asks "am I stuck", "where am I at", "hill check", "I'm going in circles", "I've been on this a long time", or says they think they're in the tunnel. Produces a fast diagnostic and one concrete recommended action (continue, downscope, pause, reshape, ask for help). 5 min max. Do NOT use as a shaping tool — this is a building tool.
user-invocable: true
---

# Am I Stuck — in-flight detection

A **deliberate** check during building. Not an automatic watchdog that interrupts flow — a tool the user invokes when they sense they're going in circles or are no longer sure where they stand.

**Principle:** deep focus makes it very hard to tell "still searching" from "executing" from the inside. This skill externalises that distinction with concrete questions and produces one recommended action.

**Scope:** a **diagnostic + action** tool, not emotional reframing. If the user is in distress, this skill isn't what helps — a break is.

## When to use

Explicit invocation:
- "am I stuck"
- "hill check"
- "where am I at"
- "I'm going in circles"
- "I've been on this forever"
- "I think I'm in the tunnel"

Also appropriate when the user makes a frustration remark ("why doesn't this work", "I've tried everything") — then offer:
> "Quick check with `toolbox:am-i-stuck` before continuing? Takes 3-5 min."

Do **not** fire automatically on a timer. The user invokes it when they need it.

## Flow

### Step 1 — Collect the position (4 questions)

Ask **exactly 4 questions** via `AskUserQuestion`. No more. The brevity is the value.

**Question 1 — Hill chart**

> "Where are you on the hill chart for this ticket?"
> - "Uphill — still looking for the solution"
> - "Just over the crest — I have an idea but it's unvalidated"
> - "Downhill — I know what to do, I'm executing"
> - "I don't know where I am anymore"

**Question 2 — Time invested**

> "How long have you been in this work session?"
> - "< 1h"
> - "1-2h"
> - "2-4h"
> - "More than 4h cumulative today"

**Question 3 — Internal signal**

> "How does the progress feel?"
> - "Making progress, it's just long"
> - "Going in circles, trying the same thing from different angles"
> - "Jumping between threads, each one looks promising"
> - "Out of ideas, I don't know what to try next"

**Question 4 — Scope check**

> "What you're working on **right now** — is it exactly what the ticket asks, or has it widened?"
> - "Same as the ticket, scope intact"
> - "I added one or two adjacent things that seemed relevant"
> - "I'm in a sub-problem I discovered along the way"
> - "Honestly I'm not sure it's still in the original scope"

This question externalises the scope drift that deep focus makes invisible from the inside. Anything but the first answer is a signal — not necessarily a problem, but worth diagnosing.

### Step 2 — Diagnose

Cross the answers to produce a diagnostic. The main patterns:

**Pattern 1 — Normal progress**
- Hill: uphill or downhill · Time: < 2h · Signal: making progress
→ "You're not stuck. Keep going."

**Pattern 2 — Prolonged uphill**
- Hill: uphill · Time: > 2h · Signal: circles, or thread-jumping
→ "You're in the uphill tunnel. Classic signal: it feels like searching for the solution, but you're exploring dead ends in a loop. High opportunity cost."

**Pattern 3 — False downhill**
- Hill: downhill · Time: > 2h · Signal: circles
→ "You think you're downhill but you're going in circles. That means you were still uphill — the solution you thought you had doesn't hold. You need to go back to real uphill."

**Pattern 4 — Disorientation**
- Hill: "don't know where I am" · Time: any · Signal: any
→ "You've lost the thread of the ticket. You need to re-anchor in the scope before moving forward."

**Pattern 5 — Depletion**
- Hill: any · Time: > 4h · Signal: out of ideas, or thread-jumping
→ "Likely cognitive fatigue. The internal heuristics have stopped responding. Non-negotiable break before any decision."

**Pattern 6 — External block**
- Hill: uphill · Time: > 1h · Signal: out of ideas
→ "Possibly blocked on missing external information. One question to a person, or one doc, could unblock this faster than continuing alone."

**Pattern 7 — Silent scope creep**
- Scope (Q4): adjacent things added, sub-problem discovered, or unsure
- Hill and time: any
→ "You're working on something that has slid outside the ticket. Each branch seems relevant, but the sum exceeds the scope. Cost: the original ticket doesn't ship while you build the adjacency."

This pattern **dominates the others** when detected — a false-downhill or a prolonged uphill on out-of-scope code is drift, not a block.

### Step 3 — One recommendation, concrete

Give **exactly one** concrete action, matched to the pattern:

**Pattern 1**
> "Keep going. No intervention needed. Re-check in ~1h if you want."

**Pattern 2 — Prolonged uphill**
> "Recommendation: downscope before continuing.
>
> Concretely: take 2 min to write down what you're currently trying to do. If it's more ambitious than the original scope, cut the ambitious part now. If it's inside scope, the rabbit hole is real and deserves either a 30-min spike, max, or a return to shaping."

**Pattern 3 — False downhill**
> "Recommendation: go back to explicit uphill.
>
> Concretely: drop the current solution, it doesn't hold. Return to exploration (brainstorm or sketch) before writing more code. Forcing a rewrite now just produces more code that doesn't hold."

**Pattern 4 — Disorientation**
> "Recommendation: re-read the shaping bundle.
>
> Concretely: open the original bundle (or the ticket if there's no bundle). Re-read what ships and what the first step was. Identify one concrete step that's inside scope. Do it. If you can't identify one, that's the signal to go back to shaping."

**Pattern 5 — Depletion**
> "Recommendation: non-negotiable break.
>
> Concretely: close the editor. Stand up, drink water, get off the screen for 20 min minimum. No technical or scope decisions until then. If you're still depleted when you come back, the session is done for today — the ticket will wait."

**Pattern 6 — External block**
> "Recommendation: identify what unblocks you.
>
> Concretely: ask yourself 'what would I need to know to move forward?' Write one precise sentence, in 2 min. If the answer is in the codebase, go get it. If it's in someone's head, send the message now (async is fine) and start something else while you wait."

**Pattern 7 — Silent scope creep**
> "Recommendation: cut the out-of-ticket scope now.
>
> Concretely: name in one sentence what got added or discovered outside the original scope. Three options: (a) not critical → drop it, stash or discard the changes; (b) a real sub-ticket → stash the code, file the ticket, return to the original scope; (c) actually in scope but unrecognised at shaping → go back and reshape. Choose now, not in 30 minutes."

### Step 4 — Offer the follow-up

After the recommendation, ask:

> "Want me to help execute that, or do you take it from here?"
> - "Help me with [the action]"
> - "I'll take it from here"
> - "Actually I want to go back and reshape"

Help → execute the action with the user (downscope, re-read the bundle, draft the async message).
Take it from here → step back, don't re-check without being invoked.
Reshape → name the bridge explicitly: which tool/context they should switch to, and what to say when they get there.

### Step 5 — Note the pattern for the retrospective

If the user hit pattern 2, 3, 5 or 6 on this ticket, record it so a later retrospective can use it:

```
Retrospective note for <TICKET>:
- Stuck at [timestamp/duration]
- Pattern: [name]
- Action taken: [what was done]
- Resolved: [yes/no/check later]
```

This feeds the retrospective and surfaces recurring patterns.

## Hard rules

**5 min max.** If the diagnostic takes longer, the information isn't clear enough — close with "no clear diagnostic, go back to shaping."

**One recommendation.** No menu of three options. In the tunnel = minimal decision load. One choice, clear.

**No judgment.** Never say "you should have stopped earlier" or "you should know this pattern by now." Invoking the skill was already the right move. Full stop.

**Don't force the action.** If the user wants to ignore the recommendation and continue, that's their call. Note that the check happened and move on.

## Don't

- Don't fire automatically on a timer
- Don't ask more than the 4 questions
- Don't offer multiple actions
- Don't judge the situation
- Don't moralise about work hygiene
- Don't lecture about cognitive fatigue
- Don't attempt to reshape from inside the build context — redirect instead
- Don't forget to note the pattern for the retrospective

## Output format

- No emoji
- Diagnostic in 1-2 sentences max
- Recommendation as "Recommendation: X. Concretely: [precise steps]"
- No pep talk, no "you've got this", no encouragement filler
- Factual and short
