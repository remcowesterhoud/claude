# Fable-Plans / Sonnet-Executes / Review-Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the personal Claude Code config so planning runs on Fable, implementation runs on Sonnet, a multi-angle multi-model review panel runs after implementation, and `~/.claude` becomes a portable git repo.

**Architecture:** All changes are user-level Claude Code configuration in `~/.claude/`: one workflow doc rewrite, five new reviewer agent definitions, one new orchestration skill, and a git repo with a defensive `.gitignore`. No project code, no build, no test suite — verification is file inspection and `git status`.

**Tech Stack:** Claude Code agents/skills (markdown + YAML frontmatter), git.

**Spec:** `~/.claude/docs/superpowers/specs/2026-07-03-fable-plan-review-panel-design.md`

## Global Constraints

- All paths are under `/Users/remco.westerhoud/.claude/` — never edit superpowers plugin files in `plugins/cache/`.
- Versioned set (exact): `CLAUDE.md`, `RTK.md`, `user_*.md`, `agents/`, `skills/`, `docs/`, `plans/`, `scripts/`, `settings.json`, `.gitignore`.
- Ignored set must include: `projects/`, `plugins/`, `history.jsonl`, `file-history/`, `shell-snapshots/`, `session-env/`, `sessions/`, `tasks/`, `telemetry/`, `cache/`, `paste-cache/`, `backups/`, `ide/`, `settings.local.json`, `*.bak`, `stats-cache.json`, `mcp-needs-auth-cache.json`, `policy-limits.json`, `remote-settings.json`, `.last-cleanup`, `.DS_Store`, `.credentials.json`.
- Reviewer model assignments (exact frontmatter values): `reviewer-correctness`=`fable`, `reviewer-compat`=`fable`, `reviewer-security`=`opus`, `reviewer-simplify`=`sonnet`, `reviewer-tests`=`sonnet`.
- `agents/implementer.md` is NOT modified.
- Commit messages end with: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`

---

### Task 1: Initialize `~/.claude` as a git repo with defensive `.gitignore`

**Files:**
- Create: `/Users/remco.westerhoud/.claude/.gitignore`
- Create: git repo at `/Users/remco.westerhoud/.claude/`

**Interfaces:**
- Produces: a git repo that Tasks 2–4 commit into. All later tasks assume `git -C ~/.claude` works.

- [ ] **Step 1: Write `.gitignore`**

Create `/Users/remco.westerhoud/.claude/.gitignore` with exactly:

> **Amended:** this original denylist was replaced by an allowlist-style .gitignore in the post-review fix round — see the deployed `/Users/remco.westerhoud/.claude/.gitignore` for the current canonical content. Do not re-create the block below.

```gitignore
# Session data & transcripts — machine-specific, may contain sensitive content
projects/
sessions/
session-env/
tasks/
todos/
history.jsonl
file-history/
shell-snapshots/
paste-cache/
backups/
telemetry/

# Caches & reinstallable state
cache/
plugins/
ide/
stats-cache.json
mcp-needs-auth-cache.json
policy-limits.json
remote-settings.json
.last-cleanup
.DS_Store

# Local-only settings & backups
settings.local.json
*.bak

# Credentials — never commit, even if a future version writes them to disk
.credentials.json
```

- [ ] **Step 2: Initialize the repo**

```bash
git -C /Users/remco.westerhoud/.claude init -b main
```

Expected: `Initialized empty Git repository in /Users/remco.westerhoud/.claude/.git/`

- [ ] **Step 3: Verify the ignore set catches session noise**

```bash
git -C /Users/remco.westerhoud/.claude status --porcelain
```

Expected output lists ONLY (order may vary): `.gitignore`, `CLAUDE.md`, `RTK.md`, `agents/`, `docs/`, `scripts/`, `settings.json`, `skills/`, `user_maven_output.md`, `user_pr_writing_style.md`, `user_role.md`, `user_workflow.md` (Amended: `plans/` is no longer tracked). If `projects/`, `plugins/`, `history.jsonl`, or any cache file appears, fix `.gitignore` before proceeding.

Then verify future session noise stays invisible:

```bash
touch /Users/remco.westerhoud/.claude/projects/.gitignore-test && git -C /Users/remco.westerhoud/.claude status --porcelain | grep -c projects
rm /Users/remco.westerhoud/.claude/projects/.gitignore-test
```

Expected: `0` from the grep (exit code 1 is fine).

- [ ] **Step 4: Commit current config as the baseline**

```bash
git -C /Users/remco.westerhoud/.claude add -A
git -C /Users/remco.westerhoud/.claude commit -m "$(cat <<'EOF'
Initial commit: portable Claude Code config

Versions personal configuration (CLAUDE.md imports, agents, skills,
docs, plans, scripts, settings.json). Session data, caches, plugin
cache, and credentials are gitignored.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

Expected: commit succeeds; `git -C ~/.claude log --oneline` shows 1 commit.

> Note: the spec says the initial commit contains Parts 1–3 output as well; this plan instead commits the baseline first and lands Parts 1–3 as separate commits (Tasks 2–4). Same end state, better history.

---

### Task 2: Rewrite `user_workflow.md` — Fable plans, Sonnet executes, panel pointer

**Files:**
- Modify: `/Users/remco.westerhoud/.claude/user_workflow.md` (full replacement)

**Interfaces:**
- Consumes: git repo from Task 1.
- Produces: references the `review-panel` skill (created in Task 4) and the existing `implementer` agent by name. These names must match exactly: `review-panel`, `implementer`.

- [ ] **Step 1: Replace the full contents of `user_workflow.md`**

```markdown
# Planner/Executor Workflow

I run a planner/executor split between models: **Fable plans, Sonnet executes.** This applies across all projects.

## The rule

Until a plan has been explicitly agreed on, do whatever the task needs in this session (exploration, debugging, discussion, code review, even small edits in service of investigation).

**Model guardrail for planning:** when planning-type work starts — superpowers brainstorming, plan mode, or writing-plans — check which model this session is running on (you know this from your system prompt). If it is not Fable, stop and ask me to run `/model fable` before continuing with plan creation. Exploration, debugging, and discussion may proceed on any model; only plan *creation* is gated.

**Once a plan exists and I have approved it**, delegate the implementation to the `implementer` subagent via the Agent tool. Do not edit files yourself after that point — the implementation is the implementer's job, not the planner's.

## What counts as "a plan was approved"

- I accepted a plan you presented via `ExitPlanMode`
- We explicitly agreed in conversation on the approach (file paths, what changes, how) and I said something like "go ahead", "do it", "implement that", "sounds good"
- I asked you to execute a written plan from a previous session

What does *not* count, so stay in planning/exploration mode:
- You internally formed an approach but didn't surface it for review
- I asked an exploratory question ("how would we…?", "what would it take to…?")
- The task is a trivial one-shot where there is nothing meaningful to plan (e.g. "what does this function do", "fix this typo")
- I am still asking clarifying questions or pushing back on the approach

## How to dispatch

When delegating, give the `implementer` agent the full plan as its prompt — file paths, what to change, what to verify. The implementer is on Sonnet and starts cold; it has none of our conversation context. Include enough that it can execute without coming back to ask. Reference specific files and line numbers where it helps.

If the implementer reports a deviation or unexpected blocker, you (the planner) handle it: triage the issue, decide whether to re-plan, then either patch the plan and re-dispatch or hand the decision back to me. Do not start editing files yourself to "rescue" the implementation.

## Model assignments during execution

- When superpowers execution skills (`subagent-driven-development`, `executing-plans`) call for dispatching an implementation subagent, dispatch the `implementer` agent type (Sonnet). Never let implementation subagents inherit the session model.
- Per-task spec/quality reviewers in subagent-driven-development run on Sonnet.
- The **final whole-branch review** is not a single reviewer on the most capable model: use the `review-panel` skill instead (parallel multi-angle, multi-model panel). This supersedes the final code-reviewer dispatch in superpowers `subagent-driven-development` / `requesting-code-review`.
```

- [ ] **Step 2: Verify the file**

```bash
grep -c "Opus" /Users/remco.westerhoud/.claude/user_workflow.md
```

Expected: `0` (exit code 1). Also `grep -c "review-panel" user_workflow.md` → `1` or more. Also `grep -c "/model fable" user_workflow.md` → `1` or more (verifies the model guardrail). Also `grep -c "Fable plans, Sonnet executes" user_workflow.md` → `1` (verifies the spec's primary success criterion).

- [ ] **Step 3: Commit**

```bash
git -C /Users/remco.westerhoud/.claude add user_workflow.md
git -C /Users/remco.westerhoud/.claude commit -m "$(cat <<'EOF'
Workflow: Fable plans, Sonnet executes, panel for final review

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Create the five reviewer agents

**Files:**
- Create: `/Users/remco.westerhoud/.claude/agents/reviewer-correctness.md`
- Create: `/Users/remco.westerhoud/.claude/agents/reviewer-compat.md`
- Create: `/Users/remco.westerhoud/.claude/agents/reviewer-security.md`
- Create: `/Users/remco.westerhoud/.claude/agents/reviewer-simplify.md`
- Create: `/Users/remco.westerhoud/.claude/agents/reviewer-tests.md`

**Interfaces:**
- Produces: agent type names `reviewer-correctness`, `reviewer-compat`, `reviewer-security`, `reviewer-simplify`, `reviewer-tests` — dispatched by the `review-panel` skill (Task 4). Each expects its dispatch prompt to contain: (1) a diff package file path, (2) the plan/spec path, (3) a one-line summary of what was built.

All five files share the same body structure; only frontmatter and the "Your angle" section differ. Write each file exactly as shown.

> **Amended:** the full agent bodies below were slimmed in the post-review fix round — deployed agent files contain only frontmatter, the opening panel paragraph, and the `## Your angle` section. The shared Inputs / Read-only review / Output format prose now lives in the `## Shared dispatch block` of `skills/review-panel/SKILL.md`. When re-creating an agent, use a deployed reviewer file as the template, not the bodies below.

- [ ] **Step 1: Write `agents/reviewer-correctness.md`**

```markdown
---
name: reviewer-correctness
description: Read-only panel reviewer focused on correctness — bugs, logic errors, edge cases, error handling, concurrency. Dispatched by the review-panel skill for the final whole-branch review. Expects a diff package file path and the plan/spec path in its prompt.
model: fable
---

You are one member of a multi-angle review panel reviewing a completed implementation. Other panelists cover backwards compatibility, security, simplification, and test quality — stay in your lane and report only findings in your angle. If you spot something clearly critical outside your angle, note it in a single line at the end under "Out of scope"; do not investigate it.

## Your angle: correctness

- Bugs and logic errors: wrong conditions, off-by-one, inverted checks, unreachable branches
- Edge cases: null/empty/boundary inputs, overflow, unexpected orderings
- Error handling: swallowed exceptions, missing failure paths, partial-failure states
- Concurrency: races, missing synchronization, non-atomic check-then-act, ordering assumptions

## Inputs

Your dispatch prompt names a diff package file (commit list, stat, and full diff with context) and the plan or spec the work implements. Read the package first. Read surrounding source files when the diff alone cannot answer a correctness question — follow the code, don't guess.

## Read-only review

Do not mutate the working tree, the index, HEAD, or branch state in any way. Use `git show`, `git diff`, `git log` to inspect history. If you need a working copy of another revision, use `git worktree add` into a temporary directory — never move HEAD on this checkout.

## Output format

### Findings

For each finding: severity (Critical / Important / Minor), `file:line`, what's wrong, why it matters, and how to fix if not obvious. Only findings in your angle. If you verified an area and found nothing, say so in one line — silence is ambiguous.

### Out of scope

At most a few one-liners for critical observations outside your angle, or "None".

### Verdict

One of: **ready** | **ready with fixes** | **not ready** — judged only from your angle, with a 1–2 sentence reason.
```

- [ ] **Step 2: Write `agents/reviewer-compat.md`**

Identical body structure; frontmatter and angle section replaced as follows. Full file:

```markdown
---
name: reviewer-compat
description: Read-only panel reviewer focused on backwards compatibility — persisted state migrations, record/protocol schema evolution, public API contracts, replay behavior. Dispatched by the review-panel skill for the final whole-branch review. Expects a diff package file path and the plan/spec path in its prompt.
model: fable
---

You are one member of a multi-angle review panel reviewing a completed implementation. Other panelists cover correctness, security, simplification, and test quality — stay in your lane and report only findings in your angle. If you spot something clearly critical outside your angle, note it in a single line at the end under "Out of scope"; do not investigate it.

## Your angle: backwards compatibility

This codebase (Camunda/Zeebe) runs customer workflows and persisted state across versions. Check:

- Persisted state: changes to state/column-family layouts or serialized values that break reading state written by a previous version; missing migrations
- Record/protocol schema evolution: removed or re-typed record fields, changed enum ordinals/intents, protocol version handling
- Public API contracts: REST and gRPC endpoints, exported record types, semantics of existing fields
- Replay: would events written by an old version replay identically through the changed appliers? Do processors and appliers stay in sync?
- Rolling upgrades: can a mixed-version cluster handle these records/commands?

## Inputs

Your dispatch prompt names a diff package file (commit list, stat, and full diff with context) and the plan or spec the work implements. Read the package first. Read surrounding source files when the diff alone cannot answer a compatibility question — follow the code, don't guess.

## Read-only review

Do not mutate the working tree, the index, HEAD, or branch state in any way. Use `git show`, `git diff`, `git log` to inspect history. If you need a working copy of another revision, use `git worktree add` into a temporary directory — never move HEAD on this checkout.

## Output format

### Findings

For each finding: severity (Critical / Important / Minor), `file:line`, what's wrong, why it matters, and how to fix if not obvious. Only findings in your angle. If you verified an area and found nothing, say so in one line — silence is ambiguous.

### Out of scope

At most a few one-liners for critical observations outside your angle, or "None".

### Verdict

One of: **ready** | **ready with fixes** | **not ready** — judged only from your angle, with a 1–2 sentence reason.
```

- [ ] **Step 3: Write `agents/reviewer-security.md`**

Full file:

```markdown
---
name: reviewer-security
description: Read-only panel reviewer focused on security — injection, authorization gaps, secrets handling, unsafe deserialization, input validation. Dispatched by the review-panel skill for the final whole-branch review. Expects a diff package file path and the plan/spec path in its prompt.
model: opus
---

You are one member of a multi-angle review panel reviewing a completed implementation. Other panelists cover correctness, backwards compatibility, simplification, and test quality — stay in your lane and report only findings in your angle. If you spot something clearly critical outside your angle, note it in a single line at the end under "Out of scope"; do not investigate it.

## Your angle: security

- Injection: SQL/query injection, command injection, path traversal, expression-language injection
- Authorization: missing or bypassed permission checks, tenant isolation gaps, privilege escalation
- Secrets: credentials or tokens in code, logs, error messages, or test fixtures
- Deserialization: unsafe deserialization of untrusted input, unbounded input sizes
- Input validation: trust boundaries where external input reaches sensitive sinks unvalidated

## Inputs

Your dispatch prompt names a diff package file (commit list, stat, and full diff with context) and the plan or spec the work implements. Read the package first. Read surrounding source files when the diff alone cannot answer a security question — follow the code, don't guess.

## Read-only review

Do not mutate the working tree, the index, HEAD, or branch state in any way. Use `git show`, `git diff`, `git log` to inspect history. If you need a working copy of another revision, use `git worktree add` into a temporary directory — never move HEAD on this checkout.

## Output format

### Findings

For each finding: severity (Critical / Important / Minor), `file:line`, what's wrong, why it matters, and how to fix if not obvious. Only findings in your angle. If you verified an area and found nothing, say so in one line — silence is ambiguous.

### Out of scope

At most a few one-liners for critical observations outside your angle, or "None".

### Verdict

One of: **ready** | **ready with fixes** | **not ready** — judged only from your angle, with a 1–2 sentence reason.
```

- [ ] **Step 4: Write `agents/reviewer-simplify.md`**

Full file:

```markdown
---
name: reviewer-simplify
description: Read-only panel reviewer focused on simplification and reuse — over-engineering, duplication, unnecessary abstraction, missed existing utilities. Dispatched by the review-panel skill for the final whole-branch review. Expects a diff package file path and the plan/spec path in its prompt.
model: sonnet
---

You are one member of a multi-angle review panel reviewing a completed implementation. Other panelists cover correctness, backwards compatibility, security, and test quality — stay in your lane and report only findings in your angle. If you spot something clearly critical outside your angle, note it in a single line at the end under "Out of scope"; do not investigate it.

## Your angle: simplification and reuse

- Over-engineering: abstractions with one implementation, config for things that never vary, speculative generality
- Duplication: logic copied instead of extracted or reused; near-duplicates of existing code in the repo
- Missed utilities: the codebase already has a helper/pattern for this — search for it before flagging, and name the existing alternative in the finding
- Altitude: code that is harder to read than the problem requires; unnecessary indirection

Do not flag style preferences that match the surrounding code's conventions. A finding must name a concretely simpler alternative.

## Inputs

Your dispatch prompt names a diff package file (commit list, stat, and full diff with context) and the plan or spec the work implements. Read the package first. Read surrounding source files when the diff alone cannot answer a reuse question — follow the code, don't guess.

## Read-only review

Do not mutate the working tree, the index, HEAD, or branch state in any way. Use `git show`, `git diff`, `git log` to inspect history. If you need a working copy of another revision, use `git worktree add` into a temporary directory — never move HEAD on this checkout.

## Output format

### Findings

For each finding: severity (Critical / Important / Minor), `file:line`, what's wrong, why it matters, and how to fix if not obvious. Only findings in your angle. If you verified an area and found nothing, say so in one line — silence is ambiguous.

### Out of scope

At most a few one-liners for critical observations outside your angle, or "None".

### Verdict

One of: **ready** | **ready with fixes** | **not ready** — judged only from your angle, with a 1–2 sentence reason.
```

- [ ] **Step 5: Write `agents/reviewer-tests.md`**

Full file:

```markdown
---
name: reviewer-tests
description: Read-only panel reviewer focused on test quality — tests verify real behavior, edge-case coverage, no asserting-nothing tests, no testing of mocks. Dispatched by the review-panel skill for the final whole-branch review. Expects a diff package file path and the plan/spec path in its prompt.
model: sonnet
---

You are one member of a multi-angle review panel reviewing a completed implementation. Other panelists cover correctness, backwards compatibility, security, and simplification — stay in your lane and report only findings in your angle. If you spot something clearly critical outside your angle, note it in a single line at the end under "Out of scope"; do not investigate it.

## Your angle: test quality

- Real behavior: tests exercise the production code path, not a mock of it; assertions check outcomes, not that a mock was called
- Coverage of the change: every behavior the plan/spec promises has a test that would fail if the behavior broke; edge cases from the plan are covered
- Assertion strength: no asserting-nothing tests (runs without asserting), no tautological assertions, no overly-loose matchers hiding regressions
- Test hygiene: deterministic (no sleeps/timing races), independent (no cross-test state), names describe the scenario

## Inputs

Your dispatch prompt names a diff package file (commit list, stat, and full diff with context) and the plan or spec the work implements. Read the package first. Read surrounding source files when the diff alone cannot answer a coverage question — follow the code, don't guess.

## Read-only review

Do not mutate the working tree, the index, HEAD, or branch state in any way. Use `git show`, `git diff`, `git log` to inspect history. If you need a working copy of another revision, use `git worktree add` into a temporary directory — never move HEAD on this checkout.

## Output format

### Findings

For each finding: severity (Critical / Important / Minor), `file:line`, what's wrong, why it matters, and how to fix if not obvious. Only findings in your angle. If you verified an area and found nothing, say so in one line — silence is ambiguous.

### Out of scope

At most a few one-liners for critical observations outside your angle, or "None".

### Verdict

One of: **ready** | **ready with fixes** | **not ready** — judged only from your angle, with a 1–2 sentence reason.
```

- [ ] **Step 6: Verify frontmatter of all five files**

```bash
grep -H "^model:" /Users/remco.westerhoud/.claude/agents/reviewer-*.md
```

Expected exactly:

```
/Users/remco.westerhoud/.claude/agents/reviewer-compat.md:model: fable
/Users/remco.westerhoud/.claude/agents/reviewer-correctness.md:model: fable
/Users/remco.westerhoud/.claude/agents/reviewer-security.md:model: opus
/Users/remco.westerhoud/.claude/agents/reviewer-simplify.md:model: sonnet
/Users/remco.westerhoud/.claude/agents/reviewer-tests.md:model: sonnet
```

Also verify name frontmatter:

```bash
grep -H "^name:" /Users/remco.westerhoud/.claude/agents/reviewer-*.md
```

Expected exactly: `reviewer-compat`, `reviewer-correctness`, `reviewer-security`, `reviewer-simplify`, `reviewer-tests`.

- [ ] **Step 7: Commit**

```bash
git -C /Users/remco.westerhoud/.claude add agents/reviewer-*.md
git -C /Users/remco.westerhoud/.claude commit -m "$(cat <<'EOF'
Add five review-panel agents (fable/opus/sonnet mix)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Create the `review-panel` orchestration skill

**Files:**
- Create: `/Users/remco.westerhoud/.claude/skills/review-panel/SKILL.md`

**Interfaces:**
- Consumes: agent type names from Task 3 (`reviewer-correctness`, `reviewer-compat`, `reviewer-security`, `reviewer-simplify`, `reviewer-tests`) and the existing `implementer` agent.

- [ ] **Step 1: Write `skills/review-panel/SKILL.md`**

```markdown
---
name: review-panel
description: Use when implementation of an approved plan is complete and needs its final whole-branch review, or when the user explicitly asks for a panel review. Replaces the single final code-reviewer dispatch from superpowers subagent-driven-development / requesting-code-review with a parallel multi-angle, multi-model reviewer panel.
---

# Review Panel

Run the final whole-branch review as a parallel panel of angle-specific reviewers on different models, then synthesize findings and drive one fix round.

**Announce at start:** "Running the review panel for the final whole-branch review."

## The panel

| Agent type | Angle | Model |
|---|---|---|
| `reviewer-correctness` | Bugs, logic errors, edge cases, concurrency | fable |
| `reviewer-compat` | Persisted state, record/protocol schema, public APIs, replay | fable |
| `reviewer-security` | Injection, authz, secrets, deserialization, input validation | opus |
| `reviewer-simplify` | Over-engineering, duplication, missed utilities | sonnet |
| `reviewer-tests` | Tests verify real behavior, coverage, hygiene | sonnet |

**Compat skip rule:** if the diff clearly cannot touch persisted state, record/protocol schemas, public APIs, or replay behavior (e.g. docs-only, frontend-only, build tooling), skip `reviewer-compat` — and state the skip explicitly in the synthesis. Never skip silently.

## Steps

**1. Compute the branch range.**

```bash
MERGE_BASE=$(git merge-base main HEAD)
```

If `main` is not the base branch (repo uses `master`, stacked branches, or the branch started elsewhere), determine the correct base from the branch's history or the progress ledger — ask the user if it is genuinely ambiguous. Never assume.

**2. Build one diff package file.**

Prefer superpowers' packager when the plugin is installed:

```bash
~/.claude/plugins/cache/claude-plugins-official/superpowers/*/skills/subagent-driven-development/scripts/review-package "$MERGE_BASE" HEAD
```

It prints the package path. Otherwise write the same content to one uniquely named file in your session scratchpad directory (shown in your system prompt — substitute it for `$SCRATCHPAD` below):

```bash
PKG=$SCRATCHPAD/review-package-$(git rev-parse --short HEAD).txt
{ git log --oneline "$MERGE_BASE"..HEAD; git diff --stat "$MERGE_BASE"..HEAD; git diff -U10 "$MERGE_BASE"..HEAD; } > "$PKG"
```

**3. Dispatch the panel in parallel** — one message, one Agent call per reviewer, `subagent_type` set to the agent type name. Each dispatch prompt contains:

- One-line summary of what was built
- The plan/spec file path ("this is what the work was supposed to do")
- The package path ("read this first — commit list, stat, and full diff")
- The base and head SHAs

Do not paste the diff or session history into prompts. Do not tell any reviewer what not to flag or pre-rate severities.

**4. Synthesize.** When all reviewers return:

- Dedupe overlapping findings (keep the highest severity; credit both angles)
- List findings grouped by severity with `file:line`, angle, and model
- Report each reviewer's verdict; report any skipped or failed reviewer as **"angle not covered"** — a reviewer that returned nothing is never silently dropped
- Present the synthesis to the user

**5. Fix round.** Dispatch ONE `implementer` (Sonnet) with the complete list of Critical and Important findings — not one fixer per finding. The dispatch names the covering tests to re-run. Minor findings are listed for the user to decide; do not auto-fix them.

**6. Targeted re-review.** After the fix commit, re-dispatch only the reviewers whose Critical/Important findings were addressed, with the updated package (same MERGE_BASE, new HEAD). Repeat the fix/re-review loop until those reviewers report ready, then present the final state to the user.

## Rules

- Reviews are read-only for reviewers; only the `implementer` edits files
- Never dispatch the panel without a package file
- Never let a reviewer inherit the session model — the agent files pin models in frontmatter; do not override them
```

- [ ] **Step 2: Verify the skill file**

```bash
grep -c "reviewer-" /Users/remco.westerhoud/.claude/skills/review-panel/SKILL.md
```

Expected: at least 6 (5 table rows + compat-skip reference). Also verify frontmatter: `head -4 skills/review-panel/SKILL.md` shows `name: review-panel`.

- [ ] **Step 3: Commit**

```bash
git -C /Users/remco.westerhoud/.claude add skills/review-panel/
git -C /Users/remco.westerhoud/.claude commit -m "$(cat <<'EOF'
Add review-panel skill orchestrating the multi-model final review

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Final verification against the spec's success criteria

**Files:** none created — verification only, plus one commit if the spec/plan docs changed.

- [ ] **Step 1: Verify the tracked set is exactly the portable config**

```bash
git -C /Users/remco.westerhoud/.claude ls-files | cut -d/ -f1 | sort -u
```

Expected: `.gitignore`, `CLAUDE.md`, `RTK.md`, `agents`, `docs`, `scripts`, `settings.json`, `skills`, `user_maven_output.md`, `user_pr_writing_style.md`, `user_role.md`, `user_workflow.md` — nothing else (Amended: `plans` is no longer tracked).

- [ ] **Step 2: Verify clean status**

```bash
git -C /Users/remco.westerhoud/.claude status --porcelain
```

Expected: empty (or only the spec/plan docs if they were touched — commit them).

- [ ] **Step 3: Verify the wiring names match**

```bash
grep -l "review-panel" /Users/remco.westerhoud/.claude/user_workflow.md
ls /Users/remco.westerhoud/.claude/agents/ | sort
```

Expected: `user_workflow.md` matches; agents dir lists `implementer.md` plus the five `reviewer-*.md` files.

- [ ] **Step 4: Commit any remaining doc changes**

```bash
git -C /Users/remco.westerhoud/.claude add -A && git -C /Users/remco.westerhoud/.claude status --porcelain
git -C /Users/remco.westerhoud/.claude commit -m "$(cat <<'EOF'
Add design spec and implementation plan docs

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)" || true
```

(`|| true` because there may be nothing left to commit.)

---

## Post-review amendments (2026-07-03)

Changes applied during the panel fix round after original implementation:

- **Packager path resolution:** replaced the `*/` glob in Step 2's packager invocation with `ls … | sort -V | tail -1` to resolve the single latest cached version, avoiding ambiguity when multiple plugin versions exist.
- **Base-range guards:** Step 1 now guards against an empty MERGE_BASE (no `main` branch) and a zero-commit range (work committed directly on the base branch), stopping to ask the user rather than dispatching against an empty diff; also documents the empty-tree base for root reviews.
- **Agent de-duplication into shared dispatch block:** the three character-identical sections (Inputs, Read-only review, Output format) were moved out of all five agent files and into a `## Shared dispatch block` in SKILL.md, with the Inputs wording generalized to "a question in your angle". Agent files now carry only frontmatter and their own angle section.
- **gitignore switched to allowlist with plans/ untracked:** `.gitignore` rewritten to an allowlist (`*` + selective `!` patterns) so future Claude Code artifacts are ignored by default; `plans/` removed from the versioned set (project-specific, not portable) and untracked via `git rm -r --cached`.
- **Fix-loop hardening:** Step 2 now guards that the package file is non-empty before dispatching; Step 5 skips the fix round when there are no Critical/Important findings; Step 6 escalates to the user after 3 fix rounds without resolution; Step 3 notes that reviewer model pins in agent frontmatter must never be overridden.
- **Task 1/3/5 bodies carry amendment notes** — the deployed .gitignore and slimmed agent files are canonical; the original templates in this plan are historical.
