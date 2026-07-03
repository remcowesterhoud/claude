# Plan — Analytics exporter flamegraph profiling (#52490)

## Context

`AnalyticsExporterBenchmark` (a JMH microbenchmark run via JUnit) currently measures
per-record overhead in the analytics exporter: ~4 ns for unmatched records, ~360 ns for
`PROCESS_INSTANCE_CREATION` with OTel emit. Issue #52490 asks us to wire async-profiler
flamegraph generation into the benchmark so the PI_CREATION hot path can be inspected, then
to capture a baseline and identify the top-3 optimization candidates. This PR delivers both
the wiring and the baseline analysis (in the PR description), closing the issue in one go.

Design spec: `docs/superpowers/specs/2026-06-03-analytics-exporter-flamegraph-profiling-design.md`.
Note: the spec shows option-string separators as `;` — the correct separator is `,` (verified
against JMH 1.37 + `microbenchmarks/.../MsgpackBenchmark.java`). The plan below uses `,`.

## Approach

Extend the existing `runBenchmarks()` JUnit entry point with a single optional system
property `-Dbenchmark.profiler=<async|gc|async+gc|none>` (default `none`). When `async` is
requested, attach JMH's `AsyncProfiler` and switch `.forks(0)` → `.forks(1)` (async-profiler
requires `-agentpath` on a forked JVM). When `gc` is requested, attach `GCProfiler`. The
default (`none`) keeps `.forks(0)` so the existing IntelliJ debug-via-play-button workflow
is preserved.

Resolve the async-profiler native lib path in order: `-Dasync.profiler.lib=...` system
property → `ASYNC_PROFILER_LIB` env var → unset (let JMH attempt its own detection and fail
with a clear message). No bundling, no download — developer brings their own lib, matching
the `microbenchmarks/` README precedent.

After the wiring lands, run the benchmark locally with `-Dbenchmark.profiler=async+gc`,
capture flamegraph SVGs for all three benchmark methods, and write the baseline analysis
(top-3 candidates) directly into the PR description.

## Files to modify

### 1. `zeebe/exporters/analytics-exporter/src/test/java/io/camunda/exporter/analytics/AnalyticsExporterBenchmark.java`

Changes to `runBenchmarks()` (currently lines 156–167):

- Read the new system property `benchmark.profiler` (default `none`).
- Parse it as a set of tokens split on `+` so `async+gc` works.
- Build the `OptionsBuilder` as today; then, based on the parsed tokens:
  - If `async` is requested:
    - Resolve `libPath` from `-Dasync.profiler.lib` → `ASYNC_PROFILER_LIB` → null.
    - Build options string: `output=flamegraph,dir=target/jmh-flamegraphs` and append
      `,libPath=<resolved>` only if non-null.
    - Call `.addProfiler("async:" + options)`.
    - Override `.forks(1)` (replace the existing `.forks(0)`).
  - If `gc` is requested: call `.addProfiler("gc")`.
- Keep `.forks(0)` as the default so the IntelliJ debug path is untouched when no profiler
  is selected.

Pattern reference: `microbenchmarks/src/main/java/io/camunda/microbenchmarks/msgpack/MsgpackBenchmark.java:42`
shows the `addProfiler(String)` usage shape.

Javadoc updates:
- Class-level: keep the existing manual-invocation line; add a second line documenting
  `-Dbenchmark.profiler=async` and the lib resolution.
- `runBenchmarks()`: call out that `benchmark.profiler=async` forces `forks=1` and therefore
  breaks IntelliJ in-process debugging — developers wanting to debug should leave the flag
  unset.

Keep all changes inside `runBenchmarks()` and its Javadoc — no changes to the benchmark
methods themselves, no changes to `@Setup`/`@TearDown`, no new fields.

### 2. `zeebe/exporters/analytics-exporter/README.md`

Add a `### Microbenchmarks` subsection under the existing `## Testing` section (after
`### Integration tests (AnalyticsExporterOtelIT)` around line 301). Cover:

- One-line purpose (per-record overhead measurement).
- Default invocation: `./mvnw verify -pl zeebe/exporters/analytics-exporter -Dtest=AnalyticsExporterBenchmark -DskipTests=false -Dbenchmark=true`.
- Flamegraph invocation: same command with `-Dbenchmark.profiler=async -Dasync.profiler.lib=/path/to/libasyncProfiler.so` (or set `ASYNC_PROFILER_LIB`).
- Where SVGs land: `target/jmh-flamegraphs/`.
- One sentence pointing at the upstream async-profiler releases page
  (`https://github.com/async-profiler/async-profiler/releases`) for obtaining the native lib;
  brief mention that macOS / Linux each have their own setup steps documented upstream.

Match the surrounding terse, descriptive prose style — no headings inside the subsection.

## Verification

There is no automated test for this; the benchmark itself is the artifact. Verify by:

1. **Compile check** — module builds cleanly:
   ```
   ./mvnw verify -pl zeebe/exporters/analytics-exporter -Dquickly -DskipTests=false -T1C
   ```
   Note: when targeting a sub-module the engineer also runs `./mvnw install -Dquickly -T1C`
   at repo root before the session, per the always-green policy.

2. **Default path still works** (no regression to IntelliJ debug workflow):
   ```
   ./mvnw verify -pl zeebe/exporters/analytics-exporter \
       -Dtest=AnalyticsExporterBenchmark -DskipTests=false -Dbenchmark=true
   ```
   Expected: benchmarks run with `forks=0`, no flamegraph output, results print to stdout.

3. **Profiler path produces SVGs**:
   ```
   ./mvnw verify -pl zeebe/exporters/analytics-exporter \
       -Dtest=AnalyticsExporterBenchmark -DskipTests=false \
       -Dbenchmark=true -Dbenchmark.profiler=async+gc \
       -Dasync.profiler.lib=/opt/async-profiler/lib/libasyncProfiler.so
   ```
   Expected: `zeebe/exporters/analytics-exporter/target/jmh-flamegraphs/` contains
   `flame-cpu-*.svg` files for the three benchmark methods; GC profiler output appears in
   the JMH results table.

4. **Pre-commit hygiene** (per AGENTS.md):
   ```
   ./mvnw license:format spotless:apply -T1C
   ```

5. **Baseline + analysis** — open the three SVGs, identify the top-3 hot frames in the
   PI_CREATION path (likely candidates per the issue: OTel `LogRecordBuilder` allocation,
   `EnumMap` lookup, `SampledLogger`), and write those into the PR description with
   screenshots or links to the SVGs.

## Out of scope (do not implement)

- No shaded benchmark jar / build artifact.
- No CI job — benchmark stays developer-invoked.
- No download or bundling of `libasyncProfiler`.
- No optimization code changes — the top-3 candidates are documented for follow-up only.

## Critical files

- Edit: `zeebe/exporters/analytics-exporter/src/test/java/io/camunda/exporter/analytics/AnalyticsExporterBenchmark.java`
- Edit: `zeebe/exporters/analytics-exporter/README.md`
- Reference (no edit): `microbenchmarks/src/main/java/io/camunda/microbenchmarks/msgpack/MsgpackBenchmark.java`
- Reference (no edit): `docs/superpowers/specs/2026-06-03-analytics-exporter-flamegraph-profiling-design.md`
