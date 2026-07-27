# Planner/Executor Workflow

I run a planner/executor split between models: **Opus plans, Sonnet executes.** This applies across all projects.

## The rule

Until a plan has been explicitly agreed on, do whatever the task needs in this session (exploration, debugging, discussion, code review, even small edits in service of investigation).

**Model for planning:** plan creation (superpowers writing-plans, plan mode) runs on Opus. If the session itself is not on Opus, dispatch the planning work to a subagent with the Opus model override rather than blocking — no need to ask me to switch models. Exploration, debugging, and discussion may proceed on any model.

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

**Pre-explore before dispatching — mandatory.** Before writing the implementer prompt, verify the prompt can answer all of these without the implementer opening a single file:

- Exact file path (not directory-level) for every file to be changed
- Line range of the class/method being modified
- Signature of any method being added or changed
- The key existing code pattern the implementer should match (e.g. how a sibling processor is structured)

If any of these is missing, run an `Explore` subagent first. Do not rationalize "close enough" — a plan with approximate locations forces the implementer into an exploration phase that costs more than the Explore call would have. Embed the Explore findings verbatim in the implementer prompt.

**Scope Read calls in dispatch:** Include this instruction in every implementer dispatch: "For files over ~300 lines, use the `Read` tool with `limit` and `offset` params to read only the relevant section rather than the full file. The Read tool is not filtered by RTK — every line it returns costs tokens."

**Suppress advisor in implementers:** Include this instruction in every implementer dispatch: "Do not call advisor(). Each advisor call replays the full conversation history and is expensive. If the task is unclear, report NEEDS_CONTEXT instead — the planner will clarify and re-dispatch."

**Filter Maven output in dispatch:** Include this instruction in every implementer dispatch: "All `./mvnw` invocations must use `-q --batch-mode`. For test runs, pipe through `grep -E 'BUILD|ERROR|FAIL|Tests run'` or use `tail -n 30` to keep only the summary in context. Never dump raw Maven output."

**grep -l before content grep:** Include this instruction in every implementer dispatch: "When locating which file contains a symbol or pattern, use `grep -rl pattern dir` (filenames only) before using content grep or Read. This keeps file lists in context instead of matching lines."

If the implementer reports a deviation or unexpected blocker, you (the planner) handle it: triage the issue, decide whether to re-plan, then either patch the plan and re-dispatch or hand the decision back to me. Do not start editing files yourself to "rescue" the implementation.

## Model assignments during execution

- When superpowers execution skills (`subagent-driven-development`, `executing-plans`) call for dispatching an implementation subagent, dispatch the `implementer` agent type (Sonnet). Never let implementation subagents inherit the session model.
- **Exception — mechanical tasks:** if the approved plan is clearly mechanical, dispatch `implementer-mechanical` (Haiku) instead. A plan is mechanical when it consists entirely of: renaming (variables, methods, classes, constants), adding/removing imports, adding a plain field or getter/setter, adding a new method that contains no logic (e.g. a getter that returns a field, a delegating override), adding an enum constant, adding a record component, updating config values, fixing code formatting or Javadoc, or adding simple boilerplate with no logic. Default to Sonnet (`implementer`) whenever the plan touches engine logic, processors, event appliers, state, concurrency, authorization, protocol/schema, or test assertions — even if the change looks small.
- Per-task spec/quality reviewers in subagent-driven-development run on Sonnet.
- The **final whole-branch review** uses the standard superpowers final code-reviewer dispatch in `subagent-driven-development` / `requesting-code-review` — no `review-panel` by default (too expensive for routine use). Only use `review-panel` when the user explicitly asks for a panel review.

## PR and review writing

`user_pr_writing_style.md` is **not** loaded by default (it would otherwise inflate every subagent's context). Read it explicitly before drafting a PR description, a PR review comment, or a standup PR summary:

```
Read: ~/.claude/user_pr_writing_style.md
```
