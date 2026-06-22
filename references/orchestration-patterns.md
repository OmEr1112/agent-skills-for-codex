# Orchestration Patterns

Reference catalog of agent orchestration patterns this repo endorses, plus anti-patterns to avoid. Read this before adding a new slash command that coordinates multiple personas, or before introducing a new persona that "wraps" existing ones.

The governing rule: **the user (or a slash command) is the orchestrator. Personas do not invoke other personas.** Skills are mandatory hops inside a persona's workflow.

---

## Endorsed patterns

### 1. Direct invocation (no orchestration)

Single persona, single perspective, single artifact. The default and the cheapest option.

```
user → code-reviewer → report → user
```

**Use when:** the work is one perspective on one artifact and you can describe it in one sentence.

**Examples:**
- "Review this PR" → `code-reviewer`
- "Find security issues in `auth.ts`" → `security-auditor`
- "What tests are missing for the checkout flow?" → `test-engineer`

**Cost:** one round trip. The baseline you should always compare orchestrated patterns against.

---

### 2. Single-persona slash command

A slash command that wraps one persona with the project's skills. Saves the user from re-explaining the workflow every time.

```
/review → code-reviewer (with code-review-and-quality skill) → report
```

**Use when:** the same single-persona invocation happens repeatedly with the same setup.

**Examples in this repo:** `/review`, `/test`, `/code-simplify`.

**Cost:** same as direct invocation. The slash command is just a saved prompt.

**Anti-signal:** if the slash command's body is mostly "decide which persona to call," delete it and let the user call the persona directly.

---

### 3. Parallel fan-out with merge

Multiple personas operate on the same input concurrently, each producing an independent report. A merge step (in the main agent's context) synthesizes them into a single decision.

```
                    ┌─→ code-reviewer    ─┐
/ship → fan out  ───┼─→ security-auditor ─┤→ merge → go/no-go + rollback
                    └─→ test-engineer    ─┘
```

**Use when:**
- The sub-tasks are genuinely independent (no shared mutable state, no ordering dependency)
- Each sub-agent benefits from its own context window
- The merge step is small enough to stay in the main context
- Wall-clock latency matters

**Examples in this repo:** `/ship`.

**Cost:** N parallel sub-agent contexts + one merge turn. Higher than direct invocation, but faster wall-clock and produces better reports because each sub-agent stays focused on its single perspective.

**Validation checklist before adopting this pattern:**
- [ ] Can I run all sub-agents at the same time without ordering issues?
- [ ] Does each persona produce a different *kind* of finding, not just the same finding from a different angle?
- [ ] Will the merge step fit in the main agent's remaining context?
- [ ] Is the user's wait time long enough that parallelism is actually noticeable?

If any answer is "no," fall back to direct invocation or a single-persona command.

---

### 4. Sequential pipeline as user-driven slash commands

The user runs slash commands in a defined order, carrying context (or commit history) between them. There is no orchestrator agent — the user IS the orchestrator.

```
user runs:  /spec  →  /plan  →  /build  →  /test  →  /review  →  /ship
```

**Use when:** the workflow has dependencies (each step needs the previous step's output) and human judgment between steps adds value.

**Examples in this repo:** the entire DEFINE → PLAN → BUILD → VERIFY → REVIEW → SHIP lifecycle.

**Cost:** one sub-agent context per step. Free for the orchestration layer because there is no orchestrator agent.

**Why not automate it:** an LLM "lifecycle orchestrator" would (a) lose nuance between steps because it has to summarize for hand-off, (b) skip the human checkpoints that catch wrong-direction work early, and (c) double the token cost via paraphrasing turns.

---

### 5. Research isolation (context preservation)

When a task requires reading large amounts of material that shouldn't pollute the main context, spawn a research sub-agent that returns only a digest.

```
main agent → research sub-agent (reads 50 files) → digest → main agent continues
```

**Use when:**
- The main session needs to stay focused on a downstream task
- The investigation result is much smaller than the input it consumes
- The decision quality benefits from the main agent having room to think after

**Examples:** "Find every call site of this deprecated API across the monorepo," "Summarize what these 30 ADRs say about caching."

**Cost:** one isolated sub-agent context. Worth it any time the alternative is loading hundreds of files into the main context.

**On Codex, use the built-in `explorer` subagent** rather than defining a custom research persona. `explorer` is designed for specific read-only codebase questions and returns a digest to the main session. Define a custom research role only when `explorer` does not fit the domain-specific prompt you need.

---

## Codex Compatibility

This catalog is packaged for Codex. The orchestration rules map to Codex skills, slash-command shims, and multi-agent tools.

### Where personas live

Codex roles are registered through `agents.<name>` entries in `~/.codex/config.toml` or trusted project `.codex/config.toml` files. This plugin ships role configs in `.codex/agents/*.config.toml` and registers `code-reviewer`, `security-auditor`, and `test-engineer`.

### Subagents vs. Main-Session Coordination

Codex parallel fan-out uses `spawn_agent`. If roles need to challenge each other, keep that debate in the main session by comparing their returned reports, or deliberately spawn follow-up agents with focused prompts.

| | Codex Subagents | Main-Session Coordination |
|--|-----------|-------------|
| Coordination | Main Codex session fans out; agents report back | Main session compares reports, asks follow-ups, and resolves conflicts |
| Context | Own context window per subagent | Main session owns the shared state and final decision |
| When to use | Independent tasks producing reports | Cross-examination, competing hypotheses, or synthesis |
| Status | Stable when multi-agent tools are enabled | Always available in the main conversation |
| Cost | Lower | Higher if follow-up agents are spawned |

**The roles in this plugin are report-oriented.** When spawned by `/ship`, they produce independent findings for the main Codex session to merge into a single go/no-go decision.

### Codex Multi-Agent Configuration

Codex exposes multi-agent tools through `features.multi_agent`, which is stable and on by default. Custom roles use:

```toml
[agents.code-reviewer]
description = "Senior Staff Engineer persona for five-axis review across correctness, readability, architecture, security, and performance."
config_file = "agents/code-reviewer.config.toml"
nickname_candidates = ["Reviewer", "Staff Reviewer", "Code Review"]
```

`config_file` points to a TOML layer for that role; relative paths resolve from the config file that declares the role. Put machine-wide role registrations in `~/.codex/config.toml`; put project-local overrides in trusted `.codex/config.toml` files.

### Built-in Agent Types To Know About

Before defining a custom role, check whether a built-in type covers the job:

| Built-in | Purpose |
|----------|---------|
| `explorer` | Specific read-only codebase questions. Use this for Pattern 5 (research isolation). |
| `worker` | Bounded implementation or fix tasks with a clear write scope. |
| `default` | General subagent behavior when no custom role is needed. |

Do not redefine built-ins. Layer specialist roles (`code-reviewer`, `security-auditor`, `test-engineer`) on top of the built-in model.

### Spawning Multiple Subagents In Parallel

In Codex, parallel fan-out (Pattern 3) requires issuing multiple `spawn_agent` calls in the same assistant turn. Sequential turns serialize execution. `/ship` calls this out explicitly. Any new orchestrator command should do the same.

---

## Worked Example: Competing-Hypothesis Debugging

This example shows when to use Codex subagents plus main-session synthesis instead of `/ship`'s production verdict flow. The two patterns look similar from a distance — both spawn the same three roles — but the value comes from a different place.

### The scenario

> *Checkout occasionally hangs for ~30 seconds before completing. It happens roughly once every 50 sessions. No errors in logs. Started after last week's release.*

Plausible root causes (mutually exclusive, all fit the symptoms):

1. A race condition in the new payment-confirmation flow
2. An auth check that occasionally falls through to a slow synchronous network call
3. A missing index on a query that scales with cart size
4. A flaky third-party API where the SDK retries silently before timing out

A single agent may pick the first plausible theory and stop investigating. A `/ship`-style fan-out gives independent reports, but debugging needs an explicit synthesis step where the main session compares hypotheses and asks follow-up questions.

The main session should treat each role's output as evidence, not verdict. The theory that survives cross-examination is more likely to be the actual root cause.

### Why this is *not* a `/ship` job

| | `/ship` | Competing-Hypothesis Debugging |
|--|--------------------|-------------|
| Subagents see | The same diff, different lenses | Focused hypothesis prompts and follow-up questions |
| Output | Three independent reports → one merge | Evidence comparison → likely root cause |
| Right when | You want a verdict on a known artifact | You want to *find* the artifact among hypotheses |

`/ship` is a verdict; competing-hypothesis debugging is an investigation.

### The trigger prompt

Type into the main Codex session, in natural language:

```
Users report checkout hangs for ~30 seconds intermittently after last
week's release. No errors in logs.

Debug this with competing hypotheses. Spawn three subagents with these
agent types:

  - code-reviewer  — investigate race conditions and blocking calls
                     in the checkout code path
  - security-auditor — investigate auth checks, session handling,
                       and any synchronous network calls added recently
  - test-engineer  — propose tests that would distinguish between the
                     hypotheses and check coverage gaps in checkout

Return each report to the main session. Then compare the reports,
identify which hypotheses are disproven, and ask one focused follow-up
if evidence conflicts.
```

The main session spawns three role-specific agents using `agent_type`. Each agent returns an independent report; the main session owns the comparison and final conclusion.

### What happens

1. Each subagent runs in its own context window, exploring the codebase from its own lens.
2. The main session compares findings and identifies contradictions.
3. If evidence conflicts, spawn one focused follow-up agent or ask the best-fit role to investigate the disputed point.
4. `test-engineer` proposes a focused integration test for whichever theory is winning.
5. The main session synthesizes the converged finding and presents it to you.

### Cost expectation

Three role-specific agents plus follow-up synthesis costs more than a routine `/ship` pass. The justification is *quality of conclusion* — for production debugging where the wrong fix is expensive, the extra tokens are a bargain. For a routine PR review, stick with `/ship`.

### Anti-pattern in this scenario

Do **not** rebuild this as a `/debug` slash command that blindly fans out subagents. If a workflow keeps coming up, document the trigger prompt above as a snippet and keep the main Codex session responsible for comparing evidence.

### When *not* to use this pattern

- Production-bound verdict on a known diff → use `/ship`.
- One specialist perspective on one artifact → direct persona invocation.
- Sequential lifecycle (spec → plan → build) → user-driven slash commands (Pattern 4).
- Read-heavy research with a small digest → built-in `explorer` subagent.

Reach for competing-hypothesis debugging only when the main session needs multiple independent perspectives to produce the right answer.

---

## Anti-patterns

### A. Router persona ("meta-orchestrator")

A persona whose job is to decide which other persona to call.

```
/work → router-persona → "this needs a review" → code-reviewer → router (paraphrases) → user
```

**Why it fails:**
- Pure routing layer with no domain value
- Adds two paraphrasing hops → information loss + roughly 2× token cost
- The user already knew they wanted a review; they could have called `/review` directly
- Replicates the work that slash commands and intent mapping in `AGENTS.md` already do

**What to do instead:** add or refine slash commands. Document intent → command mapping in `AGENTS.md`.

---

### B. Persona that calls another persona

A `code-reviewer` that internally invokes `security-auditor` when it sees auth code.

**Why it fails:**
- Personas were designed to produce a single perspective; chaining them defeats that
- The summary the calling persona passes loses context the called persona needs
- Failure modes multiply (which persona's output format wins? whose rules apply?)
- Hides cost from the user

**What to do instead:** have the calling persona *recommend* a follow-up audit in its report. The user or a slash command runs the second pass.

---

### C. Sequential orchestrator that paraphrases

An agent that calls `/spec`, then `/plan`, then `/build`, etc. on the user's behalf.

**Why it fails:**
- Loses the human checkpoints that catch wrong-direction work
- Each hand-off summarizes context — accumulated drift over a long pipeline
- Doubles token cost: orchestrator turn + sub-agent turn for every step
- Removes user agency at exactly the points where judgment matters most

**What to do instead:** keep the user as the orchestrator. Document the recommended sequence in `README.md` and let users invoke it.

---

### D. Deep persona trees

`/ship` calls a `pre-ship-coordinator` that calls a `quality-coordinator` that calls `code-reviewer`.

**Why it fails:**
- Each layer adds latency and tokens with no decision value
- Debugging becomes a multi-level investigation
- The leaf personas lose context to multiple summarization steps

**What to do instead:** keep the orchestration depth at most 1 (slash command → personas). The merge happens in the main agent.

---

## Decision flow

When considering a new orchestrated workflow, walk this flow:

```
Is the work one perspective on one artifact?
├── Yes → Direct invocation. Stop.
└── No  → Will the same composition repeat?
         ├── No  → Direct invocation, ad hoc. Stop.
         └── Yes → Are sub-tasks independent?
                  ├── No  → Sequential slash commands run by user (Pattern 4).
                  └── Yes → Parallel fan-out with merge (Pattern 3).
                           Validate against the checklist above.
                           If any check fails → fall back to single-persona command (Pattern 2).
```

---

## When to add a new pattern to this catalog

Add a new entry only after:

1. You've used the pattern at least twice in real work
2. You can name a concrete artifact in this repo that demonstrates it
3. You can explain why an existing pattern wouldn't have worked
4. You can describe its anti-pattern shadow (what people will mistakenly build instead)

Premature catalog entries become aspirational documentation that no one follows.
