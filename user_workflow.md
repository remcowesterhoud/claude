# Planner/Executor Workflow

I run a planner/executor split across models: **Opus plans, Sonnet (or Haiku) executes.** Applies to all projects.

**The discipline (holds even if the skill below never loads):**
- Before I approve a plan, do whatever the task needs inline — exploration, debugging, discussion, review, small edits in service of investigation.
- A plan is "approved" when I accept an `ExitPlanMode` plan, or we agree on the approach in conversation and I say something like "go ahead" / "do it" / "implement that". Exploratory questions ("how would we…?") and trivial one-shots (typo, "what does this do") do NOT count — stay in exploration mode.
- **Once a plan is approved, stop editing yourself.** Delegate to the `implementer` subagent (Sonnet), or `implementer-mechanical` (Haiku) for purely mechanical plans. Don't hand-edit code to "rescue" an implementation — triage and re-dispatch.
- If planning itself needs Opus and the session isn't on Opus, dispatch planning to a subagent with the Opus override rather than blocking.

**Before dispatching an approved plan — or when deciding how to dispatch — follow the `planner-executor-workflow` skill.** It carries the mandatory pre-dispatch exploration checklist, dispatch mechanics, model-assignment rules, and deviation handling.
