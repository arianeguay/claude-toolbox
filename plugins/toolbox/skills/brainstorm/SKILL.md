---
name: brainstorm
description: Turn an open idea into a decision before anything is planned or built. Use when the WHAT is still undecided, when the user says "brainstorm", "on brainstorme", "j'ai une idée", "help me think this through", "what should this look like", "est-ce que ça vaut la peine", or describes a feature, tool or change with no settled shape. Reads the code, the tracker and memory first, asks one closed question at a time, writes the decision criteria before comparing approaches, and ends on a decided / open / out-of-scope block handed to `toolbox:plan` or filed as an issue. Do NOT use when the what is already decided (that's `toolbox:plan`) or for a single go/skip question.
user-invocable: true
---

# Brainstorm

The step before `toolbox:plan`: the idea is open, and this skill settles **what** gets built, if anything. It ends on a decision, never on a design document.

## Step 1: Read before asking

Every question costs the user energy; a question the context already answers is waste. Before the first one, read what exists:

- **The code:** grep for what the idea touches. Does something close already exist? Where would it plug in?
- **The tracker:** search open and recent issues on the same subject. A duplicate or a rejected attempt changes the conversation.
- **Memory and instructions:** CLAUDE.md, memory files, decisions earlier in the conversation. Don't re-ask what was settled.

Open with what you found, in a few lines (what exists, what's been tried), then the first question.

## Step 2: One closed question at a time

- One question per message. Never a list of questions.
- Closed: 2 to 4 options, the one you recommend first, marked `(recommended)`, each with a one-line consequence. An open question only when no option can be guessed.
- Ask only what changes the outcome. If a sensible default exists, take it and say so in one line instead of asking.
- Stop asking as soon as the approaches can be compared. Three questions is usually enough; more than five means the idea is two ideas, so say so and split it.

## Step 3: Criteria before options

Write the criteria the choice will be judged on **before** listing approaches, so the user can check the verdict against them instead of trusting a feel:

```
**Criteria**
1. <criterion>: <why it matters here>
2. ...
```

Typical: cost to build, cost to maintain, reversibility, what it depends on, what it draws on the user's energy (in their own terms if their instructions define them, e.g. spoons vs tickets).

## Step 4: Approaches, side by side

2 or 3 approaches, never more. "Don't build it" counts as one whenever it's credible.

```
**Option A: <name>**
- ✅ <pro, tied to a criterion>
- ❌ <con, and its cheap mitigation if one exists>

**Option B: <name>**
- ✅ ...
- ❌ ...

**My take:** <one-line recommendation + which criteria decide it>
```

One fact per bullet. Always close with the recommendation; don't leave the synthesis to the reader.

**The chore test.** Every approach names the recurring cost it removes (a manual step, a chore, a check someone does by hand). An approach that removes none is not rejected, it's parked: it goes to the user's ideas backlog, not into the decision. Systematizing for its own sake (a tool to watch the tool, an audit that files audits) fails this test.

## Step 5: Close on a decision

Once the user picks (or confirms your take), end with this block and nothing after it:

```
**Decided**
- <the choice, one line>
- <each sub-decision made along the way, one line>

**Open**
- <what's still unknown and what settles it> (or "none")

**Out of scope**
- <what was explicitly left out> (or "none")

**Next:** <one of: run `toolbox:plan` on this · file it as an issue · park it in <backlog> · drop it>
```

Write the block, headings included, in the conversation's language.

Then stop. Don't invoke `toolbox:plan`, don't write a design file, don't start building: the user decides the next step. If they say "file it", hand the block to the tracker as the issue description (what's missing today, desired end state, how it's verified).
