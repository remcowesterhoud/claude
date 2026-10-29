# Build Tool: Gradle First

Always build and run tests with **Gradle** (`./gradlew`), not Maven, in any repo that has a Gradle wrapper.

**Why:** I'm helping test-drive the Gradle build. Every Gradle invocation is a data point; quietly using Maven instead hides the problems we want to find.

**How to apply:**
- Use `./gradlew`, never `./mvnw` / `mvn`, for compiling, testing, formatting, and verification, including in implementer subagents and plan verification steps.
- If a Gradle build or task fails because of the build setup itself (missing task, wrong dependency, plugin issue, behavior different from Maven), **report it to me as a Gradle finding**. Don't silently fall back to Maven. Fall back only if I say so.
- Only use Maven if the repo has no Gradle wrapper, or I explicitly ask for it.

## Output filtering

Don't pipe full build output into context. Filter to just what's needed: build result, failing tests, error messages.

- **Gradle:** add `-q` (or `--console=plain` when you need task-level output) and pipe through `grep -E 'BUILD|FAILED|error:|Tests'` or `tail -n 50` when only the summary matters. Run a single test with `--tests '<Class>'` on the module's test task.
- **Maven (fallback only):** `-q --batch-mode -Dsurefire.useFile=false`, filtered the same way.
- Only fall back to full unfiltered output when actively debugging a build that fails in a way the filtered view doesn't surface.
