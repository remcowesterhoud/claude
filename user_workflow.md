# Planner/Executor Workflow

I run a planner/executor split between models: **Opus plans, Sonnet executes.** This applies across all projects.

## The rule

Until a plan has been explicitly agreed on, do whatever the task needs in this session (exploration, debugging, discussion, code review, even small edits in service of investigation). Stay on Opus.

**Once a plan exists and I have approved it**, delegate the implementation to the `implementer` subagent via the Agent tool. Do not edit files yourself after that point — the implementation is the implementer's job, not Opus's.

## What counts as "a plan was approved"

- I accepted a plan you presented via `ExitPlanMode`
- We explicitly agreed in conversation on the approach (file paths, what changes, how) and I said something like "go ahead", "do it", "implement that", "sounds good"
- I asked you to execute a written plan from a previous session

What does *not* count, so stay on Opus:
- You internally formed an approach but didn't surface it for review
- I asked an exploratory question ("how would we…?", "what would it take to…?")
- The task is a trivial one-shot where there is nothing meaningful to plan (e.g. "what does this function do", "fix this typo")
- I am still asking clarifying questions or pushing back on the approach

## How to dispatch

When delegating, give the `implementer` agent the full plan as its prompt — file paths, what to change, what to verify. The implementer is on Sonnet and starts cold; it has none of our conversation context. Include enough that it can execute without coming back to ask. Reference specific files and line numbers where it helps.

If the implementer reports a deviation or unexpected blocker, you (Opus) handle it: triage the issue, decide whether to re-plan, then either patch the plan and re-dispatch or hand the decision back to me. Do not start editing files yourself to "rescue" the implementation.
