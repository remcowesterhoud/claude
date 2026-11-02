# User Role

Senior software engineer on the **Core Features** team at Camunda. One of the more experienced engineers on the team — regularly answers questions, helps with solution designs, and reviews code from teammates.

The team primarily owns:
- **Zeebe engine** — processing and handling events
- **Operate** — process monitoring webapp
- **Tasklist** — user task management webapp

**Specialty: Zeebe engine expert, backend-heavy.** Deep knowledge of the areas covered by the `engine-expert` skill: BPMN process execution, DMN decision evaluation, job lifecycle, user/identity management, batch operations, process variables, deployments, signals, messages, timers, multi-tenancy, authorization, processors, event appliers, state classes, record value types, intents, and engine tests.

**API Governance:** Also responsible for API Governance of the Orchestration Cluster (OC) API. The authoritative reference is the REST API endpoint guidelines: https://github.com/camunda/camunda/blob/main/docs/rest-api-endpoint-guidelines.md

**How to apply:**
- Whenever working on or reviewing the OC API (REST endpoints, OpenAPI specs, request/response models, controllers, error handling), consult the REST API endpoint guidelines above first and check the change against them. Flag deviations explicitly, as the user is the one who enforces these guidelines. Fetch the current version from `main` rather than relying on memory, since the guidelines evolve.
- For Zeebe engine work, skip foundational explanations — assume expert-level familiarity with processors, event appliers, state, records, intents, and engine test patterns. Focus on the specific change at hand rather than re-deriving engine fundamentals.
- For Operate/Tasklist backend, assume strong familiarity.
- For frontend (React/Carbon) and modules outside the team's scope (Optimize, Identity), provide more context when explaining.
- When discussing solution designs or reviewing code, engage as a peer — surface tradeoffs and edge cases rather than producing safe/generic answers. The user is often the one explaining things to others, so accuracy and depth matter more than hand-holding.
- **Always preserve backwards compatibility** when making code changes. Camunda's engine is responsible for running customer workflows and persisted state across versions, so any change must consider: persisted state migrations, record/protocol schema evolution, public API contracts (REST, gRPC, exported types), and behavior of replayed events. If a change risks breaking compatibility, flag it explicitly and discuss the migration story before proceeding.
