# review-prep skill — design spec

**Date:** 2026-07-09
**Status:** Approved

## Problem

AI agents produce code faster than a senior engineer can manually review using traditional PR-by-PR workflows. The bottleneck is both volume (too many PRs) and depth (each PR takes too long). Solving per-PR speed helps drain the queue.

## Goal

A manual skill `/review-prep <PR-number>` that pre-reviews a PR before the engineer opens it, producing a structured layered output: fast triage first, optional deep review on demand. Fully terminal-based, no external services.

## Scope

- Invoked manually by the reviewer (not autonomous)
- One PR at a time
- Output is terminal-only
- Targeted at Remco reviewing teammates' PRs in camunda/camunda

## Two-phase design

### Phase 1 — Fast triage

**Input:** PR number  
**Model:** Sonnet (not Haiku — triage logic requires recognizing Zeebe-specific risk patterns)  
**What it reads:** PR title, description, changed file list (no diff content)  
**Framework:** Applies the existing `review-triage` skill logic

**Output format (terminal):**
```
PR #XXXXX — <title>
Risk: HIGH | Gate: human-in-loop
Author: <author> | <module(s)> | +NNN −NNN

Red flags: <list or "none">
Focus: <1-2 sentences on where to concentrate review effort>
```

Risk tiers follow the `review-triage` framework (Low / Medium / High), driven by:
- Blast radius: which modules are touched
- Zeebe-specific danger zones: event appliers, state classes, intent enums, persisted record types, replay-sensitive paths
- Red flags for AI-generated code: large test rewrites, removed tests, duplicate helpers, missing intent capture

After printing the triage summary, Claude asks interactively:

> **"Run deep review? [y/n]"**

### Phase 2 — Deep review (on request)

**Model:** 3× parallel Sonnet agents  
**What it reads:** Full PR diff via `gh pr diff`  
**Wall-clock time:** ~30–60s (parallel execution)

Three agents run concurrently, each with a distinct lens:

| Agent | Focus |
|-------|-------|
| **Correctness** | Bugs, logic errors, edge cases, missing error handling |
| **Zeebe-specific** | State mutations, event applier completeness, intent handling coverage, backwards compat on persisted records, replay safety |
| **Simplification** | Duplication, unnecessary abstraction, missed existing utilities |

Findings are printed in the terminal below the triage summary, grouped by lens. Each finding includes file + line reference where applicable.

## What this reuses

- `review-triage` skill — risk classification framework, red flag definitions, tier/gate logic. The Phase 1 agent prompt embeds the full content of `~/.claude/skills/review-triage/skill.md` directly, so the triage logic runs within the agent rather than as a separate skill invocation.
- `gh pr view` / `gh pr diff` — PR metadata and diff fetching
- Parallel agent dispatch pattern from `review-panel`

## What this does NOT do

- Post PR comments (terminal only)
- Send Slack messages
- Run automatically on PR assignment
- Review the full repo or run builds
- Replace the engineer's own review judgment — it front-loads attention, not replaces it

## Success criteria

- Phase 1 completes in under 20s
- Phase 2 completes in under 90s
- The focus areas in the triage output accurately predict where review issues are found in Phase 2
- The engineer feels confident skipping lines the tool cleared, and focusing on what it flagged

## Skill location

`.claude/skills/review-prep/skill.md`

Installed as a user-level skill (not project-level), since it applies to any repo where Remco reviews PRs.
