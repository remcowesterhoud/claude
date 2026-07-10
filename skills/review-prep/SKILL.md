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
