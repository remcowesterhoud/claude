# Fable-Plans / Sonnet-Executes / Multi-Model Review Panel — Design

**Date:** 2026-07-03
**Scope:** Personal Claude Code configuration in `~/.claude/` (workflow doc, agents, skills). No project code.

## Goal

Rework the planner/executor workflow so that:
1. Planning always runs on **Fable** (was Opus).
2. Implementation stays on **Sonnet** via the existing `implementer` agent.
3. When implementation of an approved plan completes, a **multi-angle, multi-model review panel** reviews the whole branch, replacing superpowers' single final code-reviewer dispatch.

## Part 1: Planning on Fable

**File:** `~/.claude/user_workflow.md` (modify)

- Replace "Opus plans, Sonnet executes" with "Fable plans, Sonnet executes"; update all references to Opus-as-planner accordingly.
- Add a guardrail: when planning-type work starts (superpowers brainstorming, plan mode, writing-plans) and the session model is not Fable, Claude stops and asks the user to run `/model fable` before continuing planning. Claude knows its own model from the system prompt, so this check is reliable. Exploration/debugging/discussion may proceed on any model; only plan *creation* is gated.
- The managed-settings pin (Sonnet 4.6 on restart) is handled by the user, not by this design.

## Part 2: Implementation stays on Sonnet

**File:** `~/.claude/agents/implementer.md` — unchanged (already `model: sonnet`).

**File:** `~/.claude/user_workflow.md` (modify)

- Add a rule: when superpowers execution skills (`subagent-driven-development`, `executing-plans`) call for dispatching an implementation subagent, dispatch the `implementer` agent type (Sonnet). Never let implementation subagents inherit the session model (now Fable).
- Per-task spec/quality reviewers in subagent-driven-development stay on Sonnet.
- The superpowers instruction to run the *final whole-branch review* on "the most capable model" is superseded by the review panel (Part 3).

## Part 3: Multi-angle review panel

### Reviewer agents

**Files:** five new agent definitions in `~/.claude/agents/`. Each is a read-only reviewer: it must not mutate the working tree, index, HEAD, or branch state. Each receives a diff package file path plus the plan/spec path in its dispatch prompt, and reports findings as Critical / Important / Minor with `file:line` references, plus a verdict (ready / with fixes / not ready). **Amended design:** agent files carry only their YAML frontmatter (name, description, model) and their angle-specific section. The shared Inputs, Read-only review, and Output format prose lives in the `## Shared dispatch block` of `skills/review-panel/SKILL.md` and is appended verbatim to every reviewer dispatch prompt; agent files do not duplicate it.

| File | Angle | Model (frontmatter) |
|---|---|---|
| `reviewer-correctness.md` | Bugs, logic errors, edge cases, error handling, concurrency | `fable` |
| `reviewer-compat.md` | Backwards compatibility: persisted state migrations, record/protocol schema evolution, public API contracts (REST, gRPC, exported types), replay behavior | `fable` |
| `reviewer-security.md` | Injection, authz gaps, secrets handling, unsafe deserialization, input validation | `opus` |
| `reviewer-simplify.md` | Over-engineering, duplication, unnecessary abstraction, missed existing utilities | `sonnet` |
| `reviewer-tests.md` | Tests verify real behavior, edge-case coverage, no asserting-nothing tests, no testing of mocks | `sonnet` |

### Orchestration skill

**File:** `~/.claude/skills/review-panel/SKILL.md` (new)

- **Trigger:** implementation of an approved plan is complete and ready for final whole-branch review (i.e., where superpowers `subagent-driven-development` / `requesting-code-review` would dispatch the single final code-reviewer), or the user explicitly asks for a panel review.
- **Steps:**
  1. Compute the branch range: `MERGE_BASE=$(git merge-base main HEAD)` (or the recorded branch start) to `HEAD`.
  2. Generate one diff package file — reuse superpowers' `subagent-driven-development/scripts/review-package MERGE_BASE HEAD` when available; otherwise write `git log --oneline`, `git diff --stat`, and `git diff -U10` for the range to a single uniquely named file.
  3. Dispatch all five reviewer agents **in parallel** (one message, five Agent calls), each with: the package path, the plan/spec path, and the instruction that its review is read-only.
  4. **Compat skip rule:** if the diff clearly cannot touch persisted state, record/protocol schemas, public APIs, or replay behavior, `reviewer-compat` may be skipped — the skip must be stated explicitly in the synthesis, never silent.
  5. Main session (Fable) synthesizes: dedupe overlapping findings, triage severity, present the combined result to the user.
  6. Critical/Important findings go to the `implementer` agent (Sonnet) as **one** fix dispatch containing the complete findings list. After fixes, re-dispatch only the reviewers whose findings were addressed. Minor findings are listed for the user to decide.

**File:** `~/.claude/user_workflow.md` (modify) — one pointer line referencing the review-panel skill so it is discoverable without loading orchestration detail into every session.

## Part 4: Version-control `~/.claude` as a portable config repo

**Goal:** make the personal Claude configuration reusable in a future dev environment via `git clone`.

- `git init` in `~/.claude` with a `.gitignore` (allowlist-style: `*` ignores everything by default, selective `!` patterns un-ignore the portable config set) that versions only portable configuration and excludes everything session-, cache-, or machine-specific. New files or directories Claude Code invents are ignored by default without requiring manual `.gitignore` updates.
- **Versioned:** `CLAUDE.md`, `RTK.md`, `user_*.md`, `agents/`, `skills/`, `docs/`, `scripts/`, `settings.json`.
- **Ignored:** `plans/` (project-specific ledgers, not portable), `projects/` (transcripts + memory), `plugins/` (reinstallable cache), `history.jsonl`, `file-history/`, `shell-snapshots/`, `session-env/`, `sessions/`, `tasks/`, `telemetry/`, `cache/`, `paste-cache/`, `backups/`, `ide/`, `settings.local.json`, `*.bak`, `stats-cache.json`, `mcp-needs-auth-cache.json`, `policy-limits.json`, `remote-settings.json`, `.last-cleanup`, `.DS_Store`.
- Verified at design time: no credentials exist on disk in `~/.claude` (macOS stores them in the Keychain) and `settings.json` contains no secrets. The `.gitignore` still defends against future additions (`.credentials.json` explicitly ignored).
- Initial commit contains the current config plus everything produced by Parts 1–3.
- Remote setup (e.g. a **private** GitHub repo) is left to the user; the design only guarantees the local repo is safe to push.

## Error handling

- A reviewer that returns nothing (dies, or user skips it) is reported as "angle not covered" in the synthesis — never silently dropped.
- If `main` is not the base branch, the skill asks for or infers the correct merge base rather than assuming.

## Out of scope

- Changing the managed-settings model pin.
- Editing superpowers plugin files (version cache; overwritten on update). All behavior layering happens via user-level files, which take precedence over skills.
- Per-task review changes beyond pinning them to Sonnet.

## Success criteria

- A planning session on the wrong model is flagged before a plan is produced.
- Implementation subagents dispatched during plan execution run on Sonnet.
- Completing a plan's implementation results in a parallel 4–5 reviewer panel run (Fable×2/Opus×1/Sonnet×2), a synthesized findings report, and a single Sonnet fix round for Critical/Important findings.
- `~/.claude` is a git repo whose tracked contents can be cloned into a fresh environment without leaking transcripts, caches, or credentials; `git status` after a normal Claude Code session shows no noise from session data.
