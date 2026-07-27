---
name: planner-executor-workflow
description: Use when a plan has been approved and implementation is about to begin, or when deciding how to dispatch implementation work. Carries the mandatory pre-dispatch exploration checklist, implementer dispatch mechanics, model assignments (Sonnet vs Haiku), and deviation handling for the planner/executor split. Plan CREATION is governed by superpowers brainstorming/writing-plans — this skill owns the execution handoff.
---

# Planner/Executor Workflow

The always-loaded gate (in `~/.claude/user_workflow.md`) carries the discipline: Opus plans, Sonnet/Haiku executes; don't self-edit after approval. This skill carries the procedure for the execution handoff. Plan *creation* is superpowers `brainstorming`/`writing-plans` territory — invoke those on Opus. This skill takes over once a plan exists and you're deciding how to dispatch it.

## What counts as "a plan was approved"

Dispatch to an executor only once one of these is true:

- I accepted a plan you presented via `ExitPlanMode`
- We explicitly agreed in conversation on the approach (file paths, what changes, how) and I said something like "go ahead", "do it", "implement that", "sounds good"
- I asked you to execute a written plan from a previous session

Does NOT count — stay in planning/exploration mode:

- You internally formed an approach but didn't surface it for review
- I asked an exploratory question ("how would we…?", "what would it take to…?")
- The task is a trivial one-shot with nothing meaningful to plan (typo fix, "what does this function do")
- I'm still asking clarifying questions or pushing back on the approach

## Pre-dispatch exploration — mandatory

Before writing the executor prompt, verify it can answer ALL of these without the executor opening a single file:

- Exact file path (not directory-level) for every file to be changed
- Line range of the class/method being modified
- Signature of any method being added or changed
- The key existing code pattern to match (e.g. how a sibling processor is structured)

If any is missing, run an `Explore` subagent first and embed its findings verbatim in the executor prompt. Do not rationalize "close enough" — a plan with approximate locations forces the executor into an exploration phase that costs more than the Explore call would have.

## How to dispatch

Give the executor the FULL plan as its prompt — it starts cold with none of our conversation context. Include file paths, what to change, what to verify, and the Explore findings. Reference specific files and line numbers where it helps.

You no longer need to repeat frugality, advisor-suppression, or Maven-filtering instructions in the dispatch prompt — the executor inherits `~/.claude/user_guardrails.md` and `user_maven_output.md` via CLAUDE.md, and its own agent definition already suppresses `advisor()`. Just give the plan.

## Model assignments

- **`implementer` (Sonnet)** — the default executor. Use for anything touching engine logic, processors, event appliers, state, concurrency, authorization, protocol/schema, or test assertions — even if the change looks small. When superpowers execution skills (`subagent-driven-development`, `executing-plans`) call for an implementation subagent, dispatch this.
- **`implementer-mechanical` (Haiku)** — only when the plan is ENTIRELY mechanical: renaming, adding/removing imports, a plain field or getter/setter, a delegating override, an enum constant, a record component, config values, formatting/Javadoc, or boilerplate with no logic. Default to Sonnet whenever there's any logic.
- **Per-task spec/quality reviewers** in subagent-driven-development run on Sonnet.
- **Final whole-branch review** uses the standard superpowers final code-reviewer dispatch (`requesting-code-review`) by default. Only dispatch `reviewer-comprehensive` directly when I explicitly ask for a comprehensive/panel-style review — it computes its own diff from git history (default base `main`; pass a different base in the dispatch prompt if needed) and covers correctness, backwards compatibility, security, and test coverage in one pass. Present its findings and stop — never dispatch it a second time on the same diff to verify fixes.

## When the executor reports back

If the executor reports a deviation or unexpected blocker, the planner (you) handles it: triage, decide whether to re-plan, then either patch the plan and re-dispatch or hand the decision back to me. Do NOT start editing files yourself to "rescue" the implementation.
