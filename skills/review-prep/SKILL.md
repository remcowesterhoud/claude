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

Run this directly (no subagent needed):

```bash
gh pr view <PR> --json number,title,author,body,files,additions,deletions
```

Apply the `review-triage` skill inline. Do NOT read the diff — only use the metadata and changed-file list from the JSON above. Pay special attention to Zeebe-specific danger zones — event appliers, state classes, intent enums, persisted record types, and replay-sensitive paths — and to AI-generated-code red flags (large test rewrites, removed tests, duplicate helpers, missing intent capture).

Invoke the skill and print its **full output** to the terminal without summarizing or truncating it.

Then, using only the PR metadata and changed-file list already fetched (no additional commands), print a **Panel reviewer recommendation** section:

```
=== Panel reviewer recommendation ===
✓  reviewer-correctness  — <one-line reason it applies, or "general correctness">
✓  reviewer-compat       — <one-line reason it applies, e.g. "touches persisted state / record types">
✓  reviewer-security     — <one-line reason it applies, e.g. "touches auth / input validation">
```

Mark any reviewer with `✗  SKIP` (instead of `✓`) if it clearly does not apply, and give a one-line reason (e.g. "docs-only, no persisted state"). Never skip silently. Apply the same compat skip rule as the review-panel skill: skip `reviewer-compat` only when the diff clearly cannot touch persisted state, record/protocol schemas, public APIs, or replay behavior. Skip `reviewer-security` only when the diff clearly cannot touch auth, authorization, input validation, secrets, or deserialization. When in doubt, keep the reviewer.

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
