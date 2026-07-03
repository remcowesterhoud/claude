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
