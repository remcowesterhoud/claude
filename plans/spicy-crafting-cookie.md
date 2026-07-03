# Refactor `DeployedResourceEntity.resourceContent` from `String` to `byte[]`

## Context

Review of the Base64 fix on `rw/coffee-radium` raised the design question: rather than Base64-encoding into a `String` field at four sites (`ResourceServices`, `ResourceCreatedHandler`, `ResourceExportHandler`) and Base64-decoding at one site (`ResponseMapper`), store the content natively as `byte[]` in `DeployedResourceEntity` and let Jackson and the JDBC driver handle the serialization to/from storage.

Jackson serializes `byte[]` to JSON as a Base64 string by default, so the ES/OpenSearch wire format is unchanged. The RDBMS column changes from `CLOB` to `BLOB`. Since 8.10 is unreleased, no migration is needed.

The end state: zero explicit `Base64.getEncoder()` / `Base64.getDecoder()` calls in the resource path.

## Changes

### Entity / model types — `String` → `byte[]`

1. `webapps-schema/src/main/java/io/camunda/webapps/schema/entities/resource/DeployedResourceEntity.java`
   - Field `resourceContent`: `String` → `byte[]`
   - Getter return / setter param: `String` → `byte[]`
   - `equals()`: switch `Objects.equals(resourceContent, that.resourceContent)` to `Arrays.equals(...)`
   - `hashCode()`: pass `Arrays.hashCode(resourceContent)` into `Objects.hash(...)` instead of the array reference
   - Add `import java.util.Arrays;`

2. `search/search-domain/src/main/java/io/camunda/search/entities/DeployedResourceEntity.java`
   - Record component `@Nullable String resourceContent` → `@Nullable byte[] resourceContent`
   - Builder field + `resourceContent(...)` method: `String` → `byte[]`

3. `db/rdbms/src/main/java/io/camunda/db/rdbms/write/domain/DeployedResourceDbModel.java`
   - Record component `String resourceContent` → `byte[] resourceContent`
   - Builder field + `resourceContent(...)` method: `String` → `byte[]`

### Producers — drop `Base64.getEncoder()...`

4. `zeebe/exporters/camunda-exporter/src/main/java/io/camunda/exporter/handlers/ResourceCreatedHandler.java` (line 69)
   - `setResourceContent(Base64.getEncoder().encodeToString(value.getResourceBytes()))` → `setResourceContent(value.getResourceBytes())`
   - Remove `import java.util.Base64;`

5. `zeebe/exporters/rdbms-exporter/src/main/java/io/camunda/exporter/rdbms/handlers/ResourceExportHandler.java` (line 66)
   - Same change against the `DeployedResourceDbModelBuilder.resourceContent(...)` call
   - Remove `import java.util.Base64;`

6. `service/src/main/java/io/camunda/service/ResourceServices.java` (lines 227-229)
   - `includeContent ? Base64.getEncoder().encodeToString(record.getResourceBytes()) : null` → `includeContent ? record.getResourceBytes() : null`
   - Remove `import java.util.Base64;`

### Consumer — drop `Base64.getDecoder()...`

7. `gateways/gateway-mapping-http/src/main/java/io/camunda/gateway/mapping/http/ResponseMapper.java` (lines 434-446)
   - `toGetResourceContentResponse`: `return new String(deployedResourceEntity.resourceContent(), StandardCharsets.UTF_8);` (drop the `Base64.getDecoder().decode(...)` step; rename the local `base64Content` → `content`)
   - `toGetResourceContentBinaryResponse`: `return deployedResourceEntity.resourceContent();` (drop the decode)
   - Remove `import java.util.Base64;`

### RDBMS storage

8. `db/rdbms/src/main/resources/mapper/DeployedResourceMapper.xml` (line 28)
   - `<arg column="RESOURCE_CONTENT" javaType="java.lang.String"/>` → `<arg column="RESOURCE_CONTENT" javaType="[B" jdbcType="BLOB"/>` (`[B` is the JVM internal name for `byte[]`, which MyBatis understands)

9. `db/rdbms-schema/src/main/resources/db/changelog/rdbms-exporter/changesets/8.10.0.xml` (line 32)
   - `<column name="RESOURCE_CONTENT" type="CLOB"/>` → `<column name="RESOURCE_CONTENT" type="BLOB"/>`
   - Modifying the existing 8.10 changeset directly is acceptable because 8.10 is unreleased — no production environment has applied it yet.

### Search storage (ES/OpenSearch mappings)

10. `webapps-schema/src/main/resources/schema/elasticsearch/create/index/camunda-deployed-resource.json` (resourceContent block)
    - `{"type": "text", "index": false}` → `{"type": "binary"}` — `binary` is the semantically correct type for content stored as Base64-encoded bytes; it is not indexed by default, matching current behaviour.

11. `webapps-schema/src/main/resources/schema/opensearch/create/index/camunda-deployed-resource.json`
    - Same change.

### Transformer — no code change required

`search/search-client-query-transformer/.../DeployedResourceEntityTransformer.java` already just forwards `value.getResourceContent()` into the constructor; once both ends are `byte[]` the call compiles unchanged.

### Tests — undo the previous Base64 assertion fix

12. `zeebe/exporters/camunda-exporter/src/test/java/io/camunda/exporter/handlers/ResourceCreatedHandlerTest.java` (line 173)
    - `assertThat(entity.getResourceContent()).isEqualTo(Base64.getEncoder().encodeToString("rpa-content".getBytes(StandardCharsets.UTF_8)));`
    - → `assertThat(entity.getResourceContent()).isEqualTo("rpa-content".getBytes(StandardCharsets.UTF_8));`
    - Remove `import java.util.Base64;` (keep `StandardCharsets`)

13. `zeebe/exporters/rdbms-exporter/src/test/java/io/camunda/exporter/rdbms/handlers/ResourceExportHandlerTest.java` (lines 120, 158)
    - Same change in both `shouldHandleCreatedRecord` and `shouldHandleReexportedRecord`
    - Remove `import java.util.Base64;` (keep `StandardCharsets`)

### Tests — check & adapt downstream

14. The implementer must inspect and fix as needed (these reference `resourceContent` and may break under the type change):
    - `zeebe/gateway-rest/src/test/java/.../controller/ResourceControllerTest.java` — `shouldGetResourceContent` and `shouldGetResourceContentBinary` build a `DeployedResourceEntity` with a `String` body; switch to `.getBytes(StandardCharsets.UTF_8)` and update the expected assertions (binary endpoint should byte-equal the raw content; text endpoint should string-equal the original).
    - `clients/java/src/test/java/io/camunda/client/resource/GetResourceContentTest.java`
    - `clients/java/src/test/java/io/camunda/client/resource/GetResourceContentBinaryTest.java`
    - `zeebe/engine/src/test/java/io/camunda/zeebe/engine/processing/resource/ResourceFetchTest.java`
    - The two integration tests already added in this branch (`qa/acceptance-tests/.../ResourceDeployIT.java` and `ResourceDeployWithoutSecondaryStorageIT.java`) — these go through the HTTP client and should be unaffected, but verify.

## Verification

Module-scoped (per CLAUDE.md guidance — no full-repo or `-am` test runs):

```bash
./mvnw install -pl webapps-schema,search/search-domain,db/rdbms,db/rdbms-schema -am -Dquickly -T1C

./mvnw verify -pl zeebe/exporters/camunda-exporter -Dtest=ResourceCreatedHandlerTest -DskipTests=false -DskipITs -Dquickly
./mvnw verify -pl zeebe/exporters/rdbms-exporter   -Dtest=ResourceExportHandlerTest    -DskipTests=false -DskipITs -Dquickly
./mvnw verify -pl zeebe/gateway-rest               -Dtest=ResourceControllerTest        -DskipTests=false -DskipITs -Dquickly
./mvnw verify -pl service                          -Dtest='*Resource*'                  -DskipTests=false -DskipITs -Dquickly
./mvnw verify -pl gateways/gateway-mapping-http    -DskipTests=false -DskipITs -Dquickly
```

Run the integration tests added in this branch end-to-end:

```bash
./mvnw verify -pl qa/acceptance-tests -Dit.test='ResourceDeployIT,ResourceDeployWithoutSecondaryStorageIT' -DskipUTs -Dquickly
```

Then format:

```bash
./mvnw license:format spotless:apply -T1C
```

## Commit hygiene

This is a self-contained refactor that improves the Base64 fix from `3476c1fd008`. Squash/fixup it into that commit (same approach used in the previous round): create with `git commit -m "fixup! fix: store resource content as Base64 to preserve binary data"` and rebase with `GIT_SEQUENCE_EDITOR=true git -c rebase.autoSquash=true rebase -i HEAD~4`. After the squash the commit message no longer fits ("Base64" is gone) — amend the message to something like `fix: store resource content as raw bytes to preserve binary data` and rewrite the body to drop Base64 references.
