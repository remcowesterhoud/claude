---
name: run-camunda
description: Use when asked to run or start the Camunda application locally for testing changes in the camunda/camunda monorepo.
---

# Run Camunda Locally

Runs **StandaloneCamunda** locally with a choice of secondary storage backend: Elasticsearch, OpenSearch, or PostgreSQL.

## 1. Check for a running environment

Check whether any of the three storage containers are currently running:

```bash
docker ps --format '{{.Names}}' | grep -E '^camunda-dev-(es|os|pg)$'
```

If one is found, tell the user which storage backend is running and ask: **"Stop the running environment?"**

- **Yes** → `docker stop <container-name>` and stop here.
- **No** → continue to step 2.

If none are running, continue to step 2.

## 2. Verify repository

Check that we're in the camunda/camunda monorepo:

```bash
git remote get-url origin 2>/dev/null | grep -q "camunda/camunda"
```

If this fails, tell the user: "This skill only works in the camunda/camunda repo." Stop.

## 3. Ask which secondary storage to use

Ask the user to choose one of: **elasticsearch**, **opensearch**, or **rdbms** (PostgreSQL).

Use `AskUserQuestion` with three options.

## 4. Ask fresh start or reuse

Ask the user: **"Start fresh or reuse existing data?"**

Use `AskUserQuestion` with two options:
- **Reuse** — keep existing container and broker data as-is
- **Fresh** — wipe everything and start clean

If **fresh**, before starting the container:
1. Remove the storage container: `docker rm -f <container-name>` (ignore errors if it doesn't exist)
2. Remove the broker data folder: `rm -rf dist/data/`

## 5. Start the appropriate container

### Elasticsearch

Container name: `camunda-dev-es`

```bash
ES_CONTAINER="camunda-dev-es"
ES_IMAGE="docker.elastic.co/elasticsearch/elasticsearch:8.19.16"

if docker ps --format '{{.Names}}' | grep -qx "$ES_CONTAINER"; then
  echo "Elasticsearch already running."
elif docker ps -a --format '{{.Names}}' | grep -qx "$ES_CONTAINER"; then
  docker start "$ES_CONTAINER"
else
  docker run -d --name "$ES_CONTAINER" \
    -p 9200:9200 \
    -e discovery.type=single-node \
    -e xpack.security.enabled=false \
    -e "ES_JAVA_OPTS=-Xms512m -Xmx1024m" \
    "$ES_IMAGE"
fi

until curl -sf http://localhost:9200/_cluster/health >/dev/null 2>&1; do printf '.'; sleep 2; done
echo "Elasticsearch ready."
```

Spring profiles: `broker,consolidated-auth,identity,tasklist,operate`

Extra env: _(none beyond the base set below)_

### OpenSearch

Container name: `camunda-dev-os`

```bash
OS_CONTAINER="camunda-dev-os"
OS_IMAGE="opensearchproject/opensearch:2.19.4"

if docker ps --format '{{.Names}}' | grep -qx "$OS_CONTAINER"; then
  echo "OpenSearch already running."
elif docker ps -a --format '{{.Names}}' | grep -qx "$OS_CONTAINER"; then
  docker start "$OS_CONTAINER"
else
  docker run -d --name "$OS_CONTAINER" \
    -p 9200:9200 \
    -e discovery.type=single-node \
    -e "plugins.security.disabled=true" \
    -e "OPENSEARCH_INITIAL_ADMIN_PASSWORD=yourStrongPassword123!" \
    -e "OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx1024m" \
    "$OS_IMAGE"
fi

until curl -sf http://localhost:9200/_cluster/health >/dev/null 2>&1; do printf '.'; sleep 2; done
echo "OpenSearch ready."
```

Spring profiles: `broker,consolidated-auth,identity,tasklist,operate`

Extra env: `CAMUNDA_DATA_SECONDARYSTORAGE_TYPE=opensearch`

Do **not** include `opensearch` in the Spring profiles — `application-opensearch.yaml` contains legacy `zeebe.broker.exporters.camundaexporter.args.connect.*` properties that conflict with the new unified config validation (`SUPPORTED_ONLY_IF_VALUES_MATCH`). Setting the type via env var avoids loading that file entirely.

### RDBMS (PostgreSQL)

Container name: `camunda-dev-pg`

```bash
PG_CONTAINER="camunda-dev-pg"
PG_IMAGE="postgres:18-alpine"

if docker ps --format '{{.Names}}' | grep -qx "$PG_CONTAINER"; then
  echo "PostgreSQL already running."
elif docker ps -a --format '{{.Names}}' | grep -qx "$PG_CONTAINER"; then
  docker start "$PG_CONTAINER"
else
  docker run -d --name "$PG_CONTAINER" \
    -p 5432:5432 \
    -e POSTGRES_USER=camunda \
    -e POSTGRES_PASSWORD=camunda \
    -e POSTGRES_DB=camunda \
    --shm-size=128mb \
    "$PG_IMAGE"
fi

until docker exec "$PG_CONTAINER" pg_isready -U camunda >/dev/null 2>&1; do printf '.'; sleep 2; done
echo "PostgreSQL ready."
```

Spring profiles: `broker,consolidated-auth,identity,tasklist,operate,rdbmsPostgres`

Extra env: _(none — `application-rdbmsPostgres.yaml` sets type, URL, user, and password)_

## 6. Check frontend assets

The baseline `-Dquickly` build sets `skip.fe.build=true` (via `parent/pom.xml`), so `operate/client`, `tasklist/client`, and `webapp/client` are built without npm — resulting in 7-file JARs with no frontend assets.

Check whether the currently-installed `operate-webjar` has frontend:

```bash
VERSION=$(grep -m1 '<version>' operate/client/pom.xml | sed 's/.*<version>\(.*\)<\/version>.*/\1/')
OPERATE_JAR=~/.m2/repository/io/camunda/operate-webjar/${VERSION}/operate-webjar-${VERSION}.jar
ENTRY_COUNT=$(jar tf "$OPERATE_JAR" 2>/dev/null | wc -l | tr -d ' ')
echo "operate-webjar entries: ${ENTRY_COUNT}"
```

- **>50 entries**: frontend is present — skip this step, remove UI-disabled env vars from step 7.
- **≤50 entries**: frontend is missing. Ask the user:

  > "Frontend assets are missing from `.m2`. Build them now? (~5 min, one-time per version, shared across all worktrees on this version)"

  Use `AskUserQuestion` with two options:
  - **Yes, build** — run the frontend build (see below), then continue without UI-disabled flags.
  - **Skip** — continue with `CAMUNDA_WEBAPPS_OPERATE_UI_ENABLED=false` and `CAMUNDA_WEBAPPS_TASKLIST_UI_ENABLED=false` in step 7.

If the user chooses to build:

```bash
./mvnw install -pl operate/client,tasklist/client,webapp/client -T1C --batch-mode
```

This is a long-running step (~5 min first time, faster on subsequent runs due to npm cache). Run it in the foreground and wait for it to complete before proceeding.

## 7. Detect and rebuild stale modules

Find Java source files that are newer than what's installed in `.m2`, then rebuild only those modules.

```bash
# Collect modified and untracked Java files
CHANGED_FILES=$(
  { git diff --name-only HEAD 2>/dev/null;
    git ls-files --others --exclude-standard 2>/dev/null; } \
  | grep '\.java$' | sort -u
)

if [ -z "$CHANGED_FILES" ]; then
  echo "No source changes detected — skipping rebuild."
else
  # Walk up from each file to find its Maven module (nearest pom.xml)
  MODULES=$(echo "$CHANGED_FILES" | while IFS= read -r f; do
    dir="$(dirname "$f")"
    while [ "$dir" != "." ]; do
      [ -f "$dir/pom.xml" ] && { echo "$dir"; break; }
      dir="$(dirname "$dir")"
    done
  done | sort -u | paste -sd ',')

  echo "Rebuilding: $MODULES"
  ./mvnw install -pl "$MODULES" -am -Dquickly -T1C --batch-mode
fi
```

If the user tells you a specific module to rebuild, use that instead.

## 8. Run StandaloneCamunda

If frontend was **skipped** in step 6, also set:
```
CAMUNDA_WEBAPPS_OPERATE_UI_ENABLED=false
CAMUNDA_WEBAPPS_TASKLIST_UI_ENABLED=false
```

Full command:

```bash
ZEEBE_BROKER_EXPORTERS_CAMUNDAEXPORTER_CLASSNAME=io.camunda.exporter.CamundaExporter \
ZEEBE_DEBUG=true \
CAMUNDA_SECURITY_AUTHENTICATION_METHOD=basic \
CAMUNDA_SECURITY_INITIALIZATION_USERS_0_USERNAME=demo \
CAMUNDA_SECURITY_INITIALIZATION_USERS_0_PASSWORD=demo \
CAMUNDA_SECURITY_INITIALIZATION_USERS_0_NAME=Demo \
CAMUNDA_SECURITY_INITIALIZATION_USERS_0_EMAIL=demo@example.com \
CAMUNDA_SECURITY_INITIALIZATION_DEFAULTROLES_ADMIN_USERS_0=demo \
  ./mvnw spring-boot:run -pl dist --batch-mode \
    -Dspring-boot.run.profiles=<profiles-from-step-5>
```

App starts on **http://localhost:8080** — log in with **demo / demo**.

This is a long-running process. Run it in the background using `run_in_background: true`.

After starting, symlink the output file to `/tmp/camunda.log` for easy access:

```bash
ln -sf <output-file-path> /tmp/camunda.log
```

Then tell the user:

```
To follow the logs: ! tail -f /tmp/camunda.log
```

## Notes

- ES and OpenSearch both bind to port 9200 — only one can run at a time
- Container data is stored in the container's writable layer; `docker rm -f` wipes it
- `dist/pom.xml` already wires the main class and JVM `--add-opens` flags — no need to pass them explicitly
