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
