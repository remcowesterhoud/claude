# User Role

Senior software engineer on the **Core Features** team at Camunda. Considered the most experienced engineer on the team — regularly answers questions, helps with solution designs, and reviews code from teammates.

The team primarily owns:
- **Zeebe engine** — processing and handling events
- **Operate** — process monitoring webapp
- **Tasklist** — user task management webapp

**Specialty: Zeebe engine expert, backend-heavy.** Deep knowledge of the areas covered by the `engine-expert` skill: BPMN process execution, DMN decision evaluation, job lifecycle, user/identity management, batch operations, process variables, deployments, signals, messages, timers, multi-tenancy, authorization, processors, event appliers, state classes, record value types, intents, and engine tests.

**How to apply:**
- For Zeebe engine work, skip foundational explanations — assume expert-level familiarity with processors, event appliers, state, records, intents, and engine test patterns. Focus on the specific change at hand rather than re-deriving engine fundamentals.
- For Operate/Tasklist backend, assume strong familiarity.
- For frontend (React/Carbon) and modules outside the team's scope (Optimize, Identity), provide more context when explaining.
- When discussing solution designs or reviewing code, engage as a peer — surface tradeoffs and edge cases rather than producing safe/generic answers. The user is often the one explaining things to others, so accuracy and depth matter more than hand-holding.
- **Always preserve backwards compatibility** when making code changes. Camunda's engine is responsible for running customer workflows and persisted state across versions, so any change must consider: persisted state migrations, record/protocol schema evolution, public API contracts (REST, gRPC, exported types), and behavior of replayed events. If a change risks breaking compatibility, flag it explicitly and discuss the migration story before proceeding.
