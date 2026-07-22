# review-prep Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a user-level Claude Code skill `/review-prep <PR>` that pre-reviews a camunda/camunda PR in two phases — fast Sonnet triage first, then optional 3-lens parallel Sonnet deep review — with terminal-only output.

**Architecture:** A single skill file (`SKILL.md`) that instructs the *executing Claude session* to orchestrate agents. Phase 1 dispatches one Sonnet `general-purpose` agent that reads PR metadata + changed-file list (no diff) and applies the `review-triage` framework (embedded by reference at runtime). The session then stops and waits for a `y/n` prompt. On `y`, Phase 2 dispatches 3 parallel Sonnet agents (correctness / Zeebe-specific / simplification lenses) that read the full diff, and the session merges and prints their findings grouped by lens.

**Tech Stack:** Claude Code skill (markdown + YAML frontmatter), `gh` CLI (`gh pr view`, `gh pr diff`), the Agent tool (`subagent_type: "general-purpose"`, `model: "sonnet"`), and the existing `review-triage` skill as an embedded framework.

## Global Constraints

- **Deliverable path (case-sensitive):** `/Users/remco.westerhoud/.claude/skills/review-prep/SKILL.md` — uppercase `SKILL.md`, matching the `review-triage` convention. **The design spec writes `skill.md` lowercase in two places; that is wrong. Use uppercase `SKILL.md` everywhere — both the deliverable and the embedded-read reference. Do not "fix" it back to lowercase.** macOS is case-insensitive but git is case-sensitive, so this matters.
- **DRY — do not duplicate the review-triage framework text.** The SKILL.md instructs the executing session to read `~/.claude/skills/review-triage/SKILL.md` at runtime and paste its full content into the Phase 1 agent's prompt. This runtime indirection is deliberate — it is NOT a placeholder gap.
- **YAGNI — one file only.** Inline the Phase 1 and Phase 2 agent prompts inside SKILL.md. Do not create separate prompt-template files; the spec does not call for them.
- **Interactive gate must block.** After printing the Phase 1 triage summary, the session must STOP and wait for the user to answer `Run deep review? [y/n]`. It must not auto-proceed to Phase 2.
- **Terminal-only.** Never post PR comments, never send Slack messages, never run builds. Include the spec's "What this does NOT do" list verbatim in the skill.
- **Argument handling:** `<PR>` accepts either a PR number (e.g. `56700`) or a full GitHub PR URL (e.g. `https://github.com/camunda/camunda/pull/56700`). Both pass straight to `gh pr view` / `gh pr diff` — no manual parsing needed.
- **Phase 1 output format** must match the spec verbatim (see Task 1 content).
- **Success criteria (verification targets):** Phase 1 < 20s, Phase 2 < 90s, focus areas predict where Phase 2 finds issues, engineer trusts cleared lines.
- **Commit style:** Conventional Commits. End commit messages with:
  ```
  Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
  ```

---

### Task 1: Write the review-prep SKILL.md

**Files:**
- Create: `/Users/remco.westerhoud/.claude/skills/review-prep/SKILL.md`

**Interfaces:**
- Consumes: `~/.claude/skills/review-triage/SKILL.md` (read at runtime and embedded into the Phase 1 agent prompt); `gh pr view`, `gh pr diff`; the Agent tool with `subagent_type: "general-purpose"`, `model: "sonnet"`.
- Produces: a user-level skill auto-invoked (or invoked via `/review-prep <PR>`) whose `description` frontmatter triggers on review-prep requests.

- [ ] **Step 1: Create the skill directory**

Run:
```bash
mkdir -p /Users/remco.westerhoud/.claude/skills/review-prep
```
Expected: directory created, no output.

- [ ] **Step 2: Write the full SKILL.md content**

Create `/Users/remco.westerhoud/.claude/skills/review-prep/SKILL.md` with EXACTLY this content:

````markdown
---
name: review-prep
description: Use when preparing to review a specific PR — pre-reviews a camunda/camunda PR in two phases (fast Sonnet triage, then optional 3-lens parallel deep review), terminal-only. Invoked as /review-prep <PR> with a PR number or full GitHub PR URL.
---

# Review Prep

Pre-review a single PR before the engineer opens it. Two layered phases: fast triage first, optional deep review on demand. Terminal-only, no external services.

## Argument

`/review-prep <PR>` — `<PR>` is either a PR number (e.g. `56700`) or a full GitHub PR URL (e.g. `https://github.com/camunda/camunda/pull/56700`). Both forms are accepted by `gh pr view` and `gh pr diff` directly; do not parse the URL yourself. If no `<PR>` was given, ask the user for a PR number or URL before continuing.

## What this does NOT do

- Post PR comments (terminal only)
- Send Slack messages
- Run automatically on PR assignment
- Review the full repo or run builds
- Replace the engineer's own review judgment — it front-loads attention, not replaces it

## Phase 1 — Fast triage

Dispatch **one** agent via the Agent tool with `subagent_type: "general-purpose"` and `model: "sonnet"`.

Before dispatching, read the full content of `~/.claude/skills/review-triage/SKILL.md` and paste it verbatim into the agent's prompt (in place of the `<<<PASTE ...>>>` marker below). This embeds the triage framework so the agent runs it directly rather than invoking a separate skill.

The agent prompt is:

> You are triaging a GitHub PR to decide how deeply it needs review. Do NOT read the diff — only read metadata and the changed-file list.
>
> Run this to gather the PR's title, description, author, and changed files (no diff content):
>
> ```bash
> gh pr view <PR> --json number,title,author,body,files,additions,deletions
> ```
>
> (Substitute `<PR>` with the number or URL provided.)
>
> Apply the following review-triage framework to classify the PR. Pay special attention to Zeebe-specific danger zones — event appliers, state classes, intent enums, persisted record types, and replay-sensitive paths — and to AI-generated-code red flags (large test rewrites, removed tests, duplicate helpers, missing intent capture).
>
> ```
> <<<PASTE FULL CONTENT OF ~/.claude/skills/review-triage/SKILL.md HERE>>>
> ```
>
> Print ONLY this structured summary to your final output, filling every field. Match this format exactly:
>
> ```
> PR #XXXXX — <title>
> Risk: HIGH | Gate: human-in-loop
> Author: <author> | <module(s)> | +NNN −NNN
>
> Red flags: <list or "none">
> Focus: <1-2 sentences on where to concentrate review effort>
> ```
>
> - `Risk` is one of Low / Medium / High per the framework.
> - `Gate` is `human-on-loop` (spot-check) or `human-in-loop` (review every merge).
> - `<module(s)>` is the module(s) touched, inferred from the changed-file paths (e.g. `zeebe/engine`, `operate`).
> - `+NNN −NNN` are the additions/deletions from the JSON.

Print the agent's triage summary to the terminal verbatim.

Then STOP and ask the user, waiting for a reply before doing anything else:

> **Run deep review? [y/n]**

Do NOT auto-proceed to Phase 2. Only continue if the user answers `y` (or an affirmative). If the user answers `n`, end here.

## Phase 2 — Deep review (on request)

Only run this after the user answered `y`.

Dispatch **3 agents in parallel** — all in a single message, each via the Agent tool with `subagent_type: "general-purpose"` and `model: "sonnet"`. Each reads the full diff and applies a distinct lens.

Every agent's prompt begins with this shared preamble:

> Read the full diff of this PR:
>
> ```bash
> gh pr diff <PR>
> ```
>
> (Substitute `<PR>` with the number or URL provided.) Review it through the lens described below. Report findings as a short bulleted list; each finding must include a `file:line` reference where applicable, and a one-line description of the issue. If you find nothing for your lens, say so explicitly. Do not post comments anywhere — return findings as text only.

Then each agent gets one of these lens sections appended:

**Agent 1 — Correctness lens:**
> Focus: bugs, logic errors, edge cases, and missing error handling. Look for off-by-one errors, unchecked nulls, incorrect conditionals, swallowed exceptions, and paths that don't handle failure.

**Agent 2 — Zeebe-specific lens:**
> Focus: Zeebe engine correctness and backwards compatibility. Check for: incomplete event appliers (state mutation without a matching applier, or an applier that doesn't fully reconstruct state), missing intent handling coverage, state mutations that aren't replay-safe, and backwards-incompatible changes to persisted record types or protocol schema. Flag anything that could break replay or state migration across versions.

**Agent 3 — Simplification lens:**
> Focus: duplication, unnecessary abstraction, and missed reuse. Look for helpers that duplicate existing utilities, over-engineered abstractions that YAGNI would cut, and code that reinvents something already available in the codebase.

When all three agents return, merge and print their findings to the terminal below the triage summary, grouped by lens with these headers:

```
=== Correctness ===
<findings or "No issues found">

=== Zeebe-specific ===
<findings or "No issues found">

=== Simplification ===
<findings or "No issues found">
```
````

- [ ] **Step 3: Verify the file was written and frontmatter is valid**

Run:
```bash
head -4 /Users/remco.westerhoud/.claude/skills/review-prep/SKILL.md
```
Expected: the YAML frontmatter block starting with `---`, `name: review-prep`, a `description:` line, and closing `---`.

- [ ] **Step 4: Commit**

```bash
cd /Users/remco.westerhoud/.claude
git add skills/review-prep/SKILL.md
git commit -m "$(cat <<'EOF'
feat: add review-prep skill

Two-phase PR pre-review skill: fast Sonnet triage (applies the
review-triage framework, no diff) then optional 3-lens parallel Sonnet
deep review (correctness / Zeebe-specific / simplification). Terminal
only — no PR comments, no Slack, no builds. Reuses review-triage by
embedding its content into the triage agent prompt at runtime.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```
Expected: one commit created on the current branch.

---

### Task 2: Manually verify against a real PR

This is a manual gate for Remco, not an automated test. A freshly written user skill generally needs a Claude Code session reload before it is discoverable, and the `[y/n]` gate needs human input — so this cannot be run end-to-end by an executor agent. Perform these checks in a fresh session.

- [ ] **Step 1: Reload and pick a real PR**

Reload the Claude Code session (so the new skill is discoverable). Pick a recent, non-trivial camunda/camunda PR that touches `zeebe/engine` (so the Zeebe danger-zone logic is exercised). Note its number.

- [ ] **Step 2: Run Phase 1 and check format + timing**

Invoke `/review-prep <PR>` with the chosen number. Verify:
- Phase 1 output matches the spec format VERBATIM: the `PR #XXXXX — <title>` header, `Risk: ... | Gate: ...` line, `Author: ... | <module(s)> | +NNN −NNN` line, blank line, `Red flags:` line, `Focus:` line.
- Every field is filled (no blanks, no placeholders).
- Phase 1 completes in under 20s (success criterion).
- The session then prints `Run deep review? [y/n]` and STOPS — it does not auto-proceed.

- [ ] **Step 3: Run Phase 2 and check grouping + timing**

Answer `y`. Verify:
- 3 lenses print, grouped under `=== Correctness ===`, `=== Zeebe-specific ===`, `=== Simplification ===`.
- Findings include `file:line` references where applicable; empty lenses say "No issues found".
- Phase 2 completes in under 90s (success criterion — parallel dispatch).

- [ ] **Step 4: Judgment check — do focus areas predict findings?**

Qualitative, not a hard gate: compare the Phase 1 `Focus:` line against where Phase 2 actually surfaced issues. They should broadly agree. If they diverge badly, note it — the triage prompt may need tuning in a follow-up. Also re-run once with a full GitHub PR URL instead of a number to confirm both argument forms resolve to the same PR.

- [ ] **Step 5: Confirm the "does NOT do" constraints held**

Verify across both phases that no PR comment was posted, no Slack message was sent, and no build was run — output was terminal-only.

---

## Self-Review

**1. Spec coverage:**
- Goal / `/review-prep <PR>` / PR number or URL → Global Constraints + SKILL.md "Argument" section. ✓
- Phase 1 (Sonnet single agent, reads metadata + file list no diff, applies review-triage) → Task 1 Phase 1. ✓
- Phase 1 output format verbatim → Task 1 SKILL.md content. ✓
- `Run deep review? [y/n]` blocking gate → Global Constraints + SKILL.md, verified in Task 2 Step 2. ✓
- Phase 2 (3 parallel Sonnet agents, correctness / Zeebe / simplification, reads full diff, grouped findings) → Task 1 Phase 2. ✓
- Reuses review-triage by embedding at runtime → Global Constraints (DRY) + SKILL.md Phase 1. ✓
- "What this does NOT do" verbatim → SKILL.md. ✓
- Success criteria (timing, prediction accuracy) → Task 2 verification. ✓
- Skill location user-level → Global Constraints deliverable path. ✓

**2. Placeholder scan:** No TBD/TODO. The `<<<PASTE ...>>>` marker is intentional runtime indirection (documented in Global Constraints), not a plan gap. All agent prompts are fully written. Format strings use `<...>` as literal template fields the agent fills — these are part of the required output format, not plan placeholders.

**3. Consistency:** `SKILL.md` uppercase used everywhere (deliverable + embedded-read). Agent dispatch parameters (`subagent_type: "general-purpose"`, `model: "sonnet"`) consistent across both phases. Lens names (Correctness / Zeebe-specific / Simplification) match between Phase 2 prompt sections and the grouped-output headers.

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-07-09-review-prep-skill.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
````
