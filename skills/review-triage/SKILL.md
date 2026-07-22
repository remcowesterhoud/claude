---
name: review-triage
description: Use when deciding how deeply to review a PR, which reviewers to involve, or whether to accept a large agentic PR
---

# Review Triage

## Data Gathering

Before doing anything, look up basic details about the PR. If you don't know yet which PR to triage, ask the user to provide a link or PR identifier.

## Overview

Match review effort to consequence. Treating all PRs identically wastes capacity on low-risk changes and underserves high-risk ones.

**Core principle:** Three variables determine the right review stack — blast radius, code lifespan, and team size — not diff size.

## Triage Inputs

| Variable | Low end | High end |
|----------|---------|----------|
| **Blast radius** | Config tweak, docs, dev-only | Payment path, auth, data migration |
| **Code lifespan** | Throwaway script, one-off demo | Long-lived, maintained system |
| **Team size** | Solo, no users | Multi-team, production users |

## Pre-Review Intake

**Require before accepting a PR for review:**
1. Stated purpose of the change
2. Reasonably-sized diff (reject sprawling changes upfront)
3. Test output proof (attached or linked)
4. Confirmation it actually ran

Agent PRs average 51% larger than human submissions. Reject or chunk oversized diffs — they get rubber-stamped or generate low-value back-and-forth.

## Review Tier Selection

| Risk | Signals | Stack |
|------|---------|-------|
| **Low** | Config, docs, no-op refactor, solo/dev-only | Linter + quick glance |
| **Medium** | Feature addition, test changes, library upgrade | Type check + tests + one AI reviewer |
| **High** | Payment path, auth, data migration, production multi-team | Type check + tests + dual AI reviewers + domain owner + security pass |

## Reviewer Stack (High-Risk PRs)

Use **heterogeneous reviewers** — each catches different problem classes.

Data point: across 146 PRs, 93.4% of issues were caught by exactly one of four AI tools. Reviewer diversity beats single-tool depth.

**Dual-model pattern:** Pair one reviewer calibrated for everyday correctness with one calibrated for production-severity failures. Adversarial coverage surfaces bugs no single reviewer detects.

**Caution:** Faster agent output does not reduce review load — it increases it. Maintain reviewer headcount even as generation speed improves.

## Red Flags → Extra Scrutiny or Reject

| Signal | Why it matters |
|--------|---------------|
| Large test rewrites | Agent likely rewrote tests to match broken behavior rather than catching failures |
| Removed tests or skipped linting | Deterministic gates were lowered — CI cannot be negotiated with |
| Degraded coverage thresholds | Deterministic gates lowered — treat as regression |
| Untrusted input flowing to LLM calls | Prompt injection vulnerability |
| Duplicate helpers (existing elsewhere) | Agent didn't search before creating; signals weak codebase awareness |
| No intent capture / no decision log | Reviewer is first human to see code with no context for why it exists |

**Read test changes before code changes.** Test rewrites are a leading indicator of substantive behavioral changes being hidden.

## Intent Capture

Require agents to attach a decision log stating:
- What was attempted
- What alternatives were ruled out
- Why this approach was chosen

This recovers the "missing reasoning" problem — reviewers otherwise reconstruct intent from diffs alone.

## Human Gates

| Decision | Human role |
|----------|-----------|
| "Should this change exist?" | Always human |
| High blast-radius merge | Human-in-loop (review every merge) |
| Intent alignment ("is this what we asked for?") | Always human |
| Accountability when production breaks | Human-owned |

**Human-on-loop (low risk):** Spot-check and audit the system. Sample diffs rather than reviewing every one.

**Human-in-loop (high risk):** Review every merge. Own the merge decision.

## Triage Result

State after applying the framework:
- **Tier:** Low / Medium / High
- **Stack:** tools and reviewers to involve
- **Red flags present:** list any triggered, or "none"
- **Gate:** Human-on-loop (spot-check) or Human-in-loop (review every merge)
- **Estimated human effort:** a realistic time estimate for the reviewer. Base it on: diff size (additions + deletions), risk tier, number of red flags, and domain complexity (e.g. engine/state changes cost more per line than config or docs). Express as a range, e.g. "5–10 min", "20–30 min", "1–2 hours". Briefly explain the main driver (e.g. "small diff, low risk" or "engine state changes need careful replay reasoning").

## Further Reading

- [Agentic Code Review](https://addyosmani.com/blog/agentic-code-review/) — Addy Osmani. Source for all frameworks and data points in this skill.