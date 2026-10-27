# Deploying a Streamlit App in `us-east4` with a Live Connection to Data in `us-central1`

> **Status:** Reference design. The service specification `secrets` syntax, `ALTER SERVICE` upgrade behaviour and egress IP lookup were checked against current Snowflake documentation (October 2026). This pattern has not been deployed as part of this repo, so test it in your own accounts before production use.

## 1. Overview

This guide describes how to run a Streamlit app on **Snowpark Container Services (SPCS)** in a Snowflake account hosted in **GCP `us-east4`**, while querying data **live** from a separate Snowflake account in **GCP `us-central1`**.

A Snowflake account is bound to a single region, and its compute runs in that region. To read data from another region **without replicating it**, the app opens an outbound Snowflake connection to the source account over the public Snowflake endpoint (or private connectivity, if configured).

![Cross-region Streamlit architecture](images/cross_region_architecture.svg)

Users sign in to the SPCS endpoint in the APP account. The Streamlit container reads the private key from a Snowflake secret, leaves the APP account through an external access integration that allows only the DATA account host, and authenticates to the DATA account as a key-pair service user. Queries run on the DATA account's warehouse under a read-only role, so the data never leaves `us-central1` except as query results.

### When to use this pattern
- The app needs **always-current** data (no replication lag).
- Query result sets are **small/moderate** (dashboards, aggregates, lookups).
- Duplicating storage in a second region is undesirable.

### When NOT to use it
- Large result sets or heavy scans pulled into the app → use **replication** or **listings with auto-fulfillment** instead.
- Strict latency requirements on every interaction.

### Trade-offs
| Factor | Impact |
|---|---|
| Freshness | Real-time |
| Latency | Added cross-region round trip per query |
| Cost | Compute in **both** accounts (SPCS in east4, warehouse in central1) + cross-region **egress** on result data |
| Ops | Two accounts' auth, network rules, and roles to manage |

---

## 2. Prerequisites

- Two Snowflake accounts in the same organization:
  - `DATA` account – GCP `us-central1` (source data)
  - `APP` account – GCP `us-east4` (Streamlit runtime)
- SPCS available in the `APP` account.
- `ACCOUNTADMIN` (or delegated roles) in both accounts.
- Local tooling: Docker, Snowflake CLI (`snow`), OpenSSL.
- Account identifier for the DATA account, e.g. `MYORG-DATA_CENTRAL`
  (host: `myorg-data_central.snowflakecomputing.com`).

Replace placeholders throughout:

| Placeholder | Example |
|---|---|
| `<ORG>` | `MYORG` |
| `<DATA_ACCT>` | `DATA_CENTRAL` |
| `<APP_ACCT>` | `APP_EAST4` |
| `<SRC_DB>` | `ANALYTICS` |

---

## 3. Configure the DATA account (`us-central1`)

### 3.1 Generate a key pair (locally)
```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```
Store `rsa_key.p8` securely; it will be loaded into a Snowflake secret in the APP account. **Never commit it to git.**

### 3.2 Create a read-only role, warehouse, and service user
```sql
USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS STREAMLIT_REMOTE_READER;

CREATE WAREHOUSE IF NOT EXISTS STREAMLIT_REMOTE_WH
  WAREHOUSE_SIZE = XSMALL
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

GRANT USAGE ON WAREHOUSE STREAMLIT_REMOTE_WH TO ROLE STREAMLIT_REMOTE_READER;
GRANT USAGE ON DATABASE <SRC_DB> TO ROLE STREAMLIT_REMOTE_READER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE <SRC_DB> TO ROLE STREAMLIT_REMOTE_READER;
GRANT SELECT ON ALL TABLES IN DATABASE <SRC_DB> TO ROLE STREAMLIT_REMOTE_READER;
GRANT SELECT ON ALL VIEWS  IN DATABASE <SRC_DB> TO ROLE STREAMLIT_REMOTE_READER;
GRANT SELECT ON FUTURE TABLES IN DATABASE <SRC_DB> TO ROLE STREAMLIT_REMOTE_READER;
GRANT SELECT ON FUTURE VIEWS  IN DATABASE <SRC_DB> TO ROLE STREAMLIT_REMOTE_READER;

CREATE USER IF NOT EXISTS SVC_STREAMLIT_EAST4
  TYPE = SERVICE
  DEFAULT_ROLE = STREAMLIT_REMOTE_READER
  DEFAULT_WAREHOUSE = STREAMLIT_REMOTE_WH
  RSA_PUBLIC_KEY = '<contents of rsa_key.pub without header/footer lines>';

GRANT ROLE STREAMLIT_REMOTE_READER TO USER SVC_STREAMLIT_EAST4;
```

> Least privilege: prefer granting on curated **secure views** rather than whole databases.

### 3.3 (Recommended) Restrict where the service user can log in from
SPCS containers connect out from Snowflake-managed IP addresses, not addresses you control. To lock the service user down to the APP account's egress ranges:

1. In the **APP** account, get the current ranges:
   ```sql
   SELECT SYSTEM$GET_SNOWFLAKE_EGRESS_IP_RANGES();
   ```
2. In the **DATA** account, allow only those ranges for the service user:
   ```sql
   CREATE NETWORK RULE APP_EAST4_EGRESS MODE = INGRESS TYPE = IPV4
     VALUE_LIST = ('<cidr_1>', '<cidr_2>');          -- ranges from step 1
   CREATE NETWORK POLICY SVC_STREAMLIT_POLICY ALLOWED_NETWORK_RULE_LIST = ('APP_EAST4_EGRESS');
   ALTER USER SVC_STREAMLIT_EAST4 SET NETWORK_POLICY = SVC_STREAMLIT_POLICY;
   ```
3. Re-run step 1 periodically. Snowflake can change the ranges, and a stale list makes logins fail even though the APP-side network rule is correct.

If you skip this, rely on key-pair auth plus the least-privilege role, and monitor `LOGIN_HISTORY` in the DATA account.

---

## 4. Configure the APP account (`us-east4`)

### 4.1 Database, schema, image repo, role
```sql
USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS STREAMLIT_APP_ADMIN;
CREATE DATABASE IF NOT EXISTS STREAMLIT_APPS;
CREATE SCHEMA  IF NOT EXISTS STREAMLIT_APPS.CROSS_REGION;
GRANT OWNERSHIP ON SCHEMA STREAMLIT_APPS.CROSS_REGION TO ROLE STREAMLIT_APP_ADMIN COPY CURRENT GRANTS;
GRANT USAGE ON DATABASE STREAMLIT_APPS TO ROLE STREAMLIT_APP_ADMIN;

CREATE IMAGE REPOSITORY IF NOT EXISTS STREAMLIT_APPS.CROSS_REGION.IMAGES;
GRANT READ, WRITE ON IMAGE REPOSITORY STREAMLIT_APPS.CROSS_REGION.IMAGES TO ROLE STREAMLIT_APP_ADMIN;

GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE STREAMLIT_APP_ADMIN;
GRANT ROLE STREAMLIT_APP_ADMIN TO USER <YOUR_USER>;
```

### 4.2 Compute pool
```sql
CREATE COMPUTE POOL IF NOT EXISTS STREAMLIT_POOL
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_XS
  AUTO_SUSPEND_SECS = 600;

GRANT USAGE, MONITOR ON COMPUTE POOL STREAMLIT_POOL TO ROLE STREAMLIT_APP_ADMIN;
```

### 4.3 Secret holding the private key
```sql
USE ROLE STREAMLIT_APP_ADMIN;
USE SCHEMA STREAMLIT_APPS.CROSS_REGION;

CREATE OR REPLACE SECRET CENTRAL_SVC_PRIVATE_KEY
  TYPE = GENERIC_STRING
  SECRET_STRING = '-----BEGIN PRIVATE KEY-----
...contents of rsa_key.p8...
-----END PRIVATE KEY-----';
```

### 4.4 Network rule + External Access Integration (egress to DATA account)
```sql
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE NETWORK RULE STREAMLIT_APPS.CROSS_REGION.CENTRAL_SNOWFLAKE_EGRESS
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = (
    '<org>-<data_acct>.snowflakecomputing.com:443'
    -- Add OCSP / stage hosts if the connector requires them, e.g.:
    -- 'ocsp.snowflakecomputing.com:80'
  );

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION CENTRAL_SNOWFLAKE_EAI
  ALLOWED_NETWORK_RULES = (STREAMLIT_APPS.CROSS_REGION.CENTRAL_SNOWFLAKE_EGRESS)
  ALLOWED_AUTHENTICATION_SECRETS = (STREAMLIT_APPS.CROSS_REGION.CENTRAL_SVC_PRIVATE_KEY)
  ENABLED = TRUE;

GRANT USAGE ON INTEGRATION CENTRAL_SNOWFLAKE_EAI TO ROLE STREAMLIT_APP_ADMIN;
```

> The role that creates the service needs READ on the secret. Here `STREAMLIT_APP_ADMIN` creates and therefore owns it; if a different role creates the service, run `GRANT READ ON SECRET STREAMLIT_APPS.CROSS_REGION.CENTRAL_SVC_PRIVATE_KEY TO ROLE <service_owner_role>;`.

> If result sets are large, the Python connector may download result chunks from cloud storage hosts. Run `SELECT SYSTEM$ALLOWLIST();` **in the DATA account** and add the required hosts to the network rule.

---

## 5. Application code

### 5.1 Repository layout

![Cross-region app repository layout](images/cross_region_repo_layout.svg)

| Path | Purpose |
|---|---|
| `app/streamlit_app.py` | Streamlit UI and the remote Snowflake connection |
| `app/requirements.txt` | Python dependencies |
| `Dockerfile` | Builds the `linux/amd64` image that runs Streamlit on port 8501 |
| `spec.yaml` | Service specification: image, env vars, secret mount, endpoint |
| `README.md` | This guide |

### 5.2 `app/requirements.txt`
```
streamlit>=1.35
snowflake-connector-python[pandas]>=3.10
cryptography>=42
pandas
```

### 5.3 `app/streamlit_app.py`
```python
import os
import pandas as pd
import streamlit as st
import snowflake.connector
from cryptography.hazmat.primitives import serialization

st.set_page_config(page_title="Cross-Region Live Data", layout="wide")

REMOTE_ACCOUNT   = os.environ["REMOTE_ACCOUNT"]      # e.g. MYORG-DATA_CENTRAL
REMOTE_USER      = os.environ["REMOTE_USER"]         # SVC_STREAMLIT_EAST4
REMOTE_ROLE      = os.environ.get("REMOTE_ROLE", "STREAMLIT_REMOTE_READER")
REMOTE_WAREHOUSE = os.environ.get("REMOTE_WAREHOUSE", "STREAMLIT_REMOTE_WH")
REMOTE_DATABASE  = os.environ.get("REMOTE_DATABASE")
PRIVATE_KEY_PEM  = os.environ["REMOTE_PRIVATE_KEY"]  # injected from Snowflake secret


def _load_private_key(pem: str) -> bytes:
    key = serialization.load_pem_private_key(pem.encode(), password=None)
    return key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )


@st.cache_resource(show_spinner=False)
def get_remote_conn():
    return snowflake.connector.connect(
        account=REMOTE_ACCOUNT,
        user=REMOTE_USER,
        private_key=_load_private_key(PRIVATE_KEY_PEM),
        role=REMOTE_ROLE,
        warehouse=REMOTE_WAREHOUSE,
        database=REMOTE_DATABASE,
        client_session_keep_alive=True,
        application="streamlit_cross_region_east4",
    )


@st.cache_data(ttl=300, show_spinner="Querying us-central1…")
def run_query(sql: str) -> pd.DataFrame:
    cur = get_remote_conn().cursor()
    try:
        cur.execute(sql)
        return cur.fetch_pandas_all()
    finally:
        cur.close()


st.title("Live data from us-central1")

try:
    info = run_query("SELECT CURRENT_ACCOUNT() AS acct, CURRENT_REGION() AS region")
    st.caption(f"Connected to {info.iloc[0]['ACCT']} in {info.iloc[0]['REGION']}")
except Exception as e:
    st.error(f"Connection failed: {e}")
    st.stop()

# Keep queries aggregated / filtered to minimize cross-region egress.
sql = st.text_area("SQL", "SELECT * FROM <SRC_DB>.PUBLIC.MY_VIEW LIMIT 100")
if st.button("Run"):
    st.dataframe(run_query(sql), use_container_width=True)
```

> For production, replace the free-form SQL box with parameterized, predefined queries.

### 5.4 `Dockerfile`
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ .
EXPOSE 8501
CMD ["streamlit", "run", "streamlit_app.py", \
     "--server.port=8501", "--server.address=0.0.0.0", \
     "--server.headless=true", "--server.enableCORS=false", \
     "--server.enableXsrfProtection=false"]
```

### 5.5 `spec.yaml`
```yaml
spec:
  containers:
    - name: streamlit
      image: /streamlit_apps/cross_region/images/streamlit-cross-region:latest
      env:
        REMOTE_ACCOUNT: MYORG-DATA_CENTRAL
        REMOTE_USER: SVC_STREAMLIT_EAST4
        REMOTE_ROLE: STREAMLIT_REMOTE_READER
        REMOTE_WAREHOUSE: STREAMLIT_REMOTE_WH
        REMOTE_DATABASE: ANALYTICS
      secrets:
        - snowflakeSecret:
            objectName: streamlit_apps.cross_region.central_svc_private_key
          secretKeyRef: secret_string
          envVarName: REMOTE_PRIVATE_KEY
      resources:
        requests: { cpu: 0.5, memory: 1G }
        limits:   { cpu: 1,   memory: 2G }
  endpoints:
    - name: ui
      port: 8501
      public: true
```

---

## 6. Build, push, deploy

### 6.1 Build and push the image
```bash
# Get repository URL
snow spcs image-repository url STREAMLIT_APPS.CROSS_REGION.IMAGES --connection app_east4
# -> <org>-<app_acct>.registry.snowflakecomputing.com/streamlit_apps/cross_region/images

REPO=<repository_url_from_above>
snow spcs image-registry login --connection app_east4

docker build --platform linux/amd64 -t $REPO/streamlit-cross-region:latest .
docker push $REPO/streamlit-cross-region:latest
```

### 6.2 Upload spec and create the service
```sql
USE ROLE STREAMLIT_APP_ADMIN;
USE SCHEMA STREAMLIT_APPS.CROSS_REGION;

CREATE STAGE IF NOT EXISTS SPECS;
-- PUT file://spec.yaml @SPECS AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

CREATE SERVICE STREAMLIT_CROSS_REGION
  IN COMPUTE POOL STREAMLIT_POOL
  FROM @SPECS
  SPECIFICATION_FILE = 'spec.yaml'
  EXTERNAL_ACCESS_INTEGRATIONS = (CENTRAL_SNOWFLAKE_EAI)
  MIN_INSTANCES = 1
  MAX_INSTANCES = 1;
```

### 6.3 Verify
```sql
SELECT SYSTEM$GET_SERVICE_STATUS('STREAMLIT_CROSS_REGION');
SHOW ENDPOINTS IN SERVICE STREAMLIT_CROSS_REGION;   -- ingress_url = app URL
CALL SYSTEM$GET_SERVICE_LOGS('STREAMLIT_CROSS_REGION', 0, 'streamlit', 100);
```

### 6.4 Grant end-user access
```sql
CREATE ROLE IF NOT EXISTS STREAMLIT_APP_USER;
GRANT USAGE ON DATABASE STREAMLIT_APPS TO ROLE STREAMLIT_APP_USER;
GRANT USAGE ON SCHEMA STREAMLIT_APPS.CROSS_REGION TO ROLE STREAMLIT_APP_USER;
GRANT SERVICE ROLE STREAMLIT_CROSS_REGION!ALL_ENDPOINTS_USAGE TO ROLE STREAMLIT_APP_USER;
```

---

## 7. Updating the app
```bash
docker build --platform linux/amd64 -t $REPO/streamlit-cross-region:latest .
docker push $REPO/streamlit-cross-region:latest
```
```sql
-- Re-apply the specification. This is what makes Snowflake pull the new image
-- and restart the containers with the new code.
ALTER SERVICE STREAMLIT_CROSS_REGION FROM @SPECS SPECIFICATION_FILE = 'spec.yaml';
```

> Do **not** use `SUSPEND` / `RESUME` to deploy new code. Per the `ALTER SERVICE` docs, resuming redeploys the same image version; it is not a service update. For traceable releases, push a new tag (for example `:v2`), update `image:` in `spec.yaml`, re-upload it to `@SPECS`, then run the `ALTER SERVICE ... FROM @SPECS` statement above.

---

## 8. Security checklist
- [ ] Service user is `TYPE = SERVICE` with key-pair auth only (no password).
- [ ] Remote role is read-only and scoped to secure views where possible.
- [ ] Private key lives only in a Snowflake secret; not in git, image, or spec.
- [ ] Network rule allows **only** the DATA account host(s).
- [ ] Endpoint access controlled via service roles.
- [ ] Rotate keys periodically (`RSA_PUBLIC_KEY_2` supports zero-downtime rotation).
- [ ] Monitor `SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY` / `QUERY_HISTORY` in the DATA account.

## 9. Cost & performance guidance
- **Push computation to the source**: aggregate/filter in SQL; return small result sets.
- **Cache** with `st.cache_data(ttl=...)` to avoid repeat cross-region queries.
- **Right-size** the remote warehouse (start XSMALL, `AUTO_SUSPEND = 60`).
- **Suspend** the compute pool / service when not needed.
- Track egress in `SNOWFLAKE.ORGANIZATION_USAGE.DATA_TRANSFER_HISTORY`.

## 10. Troubleshooting
| Symptom | Likely cause | Fix |
|---|---|---|
| Connection timeout / host unreachable | EAI not attached or host missing from network rule | Confirm `EXTERNAL_ACCESS_INTEGRATIONS` on service; check host spelling |
| `JWT token is invalid` | Public key mismatch or wrong account identifier | Re-set `RSA_PUBLIC_KEY`; use `<ORG>-<ACCT>` format |
| Hangs on large results | Result-chunk storage hosts blocked | Add hosts from `SYSTEM$ALLOWLIST()` (DATA account) to network rule |
| `Insufficient privileges` | Missing grants on remote role | Grant SELECT/USAGE in DATA account |
| Endpoint returns 403 | User lacks service role | Grant `ALL_ENDPOINTS_USAGE` service role |
| Env var `REMOTE_PRIVATE_KEY` missing | Secret ref wrong in spec | Verify `objectName` and `secretKeyRef: secret_string` |

## 11. Applying this to the Boston Dynamics demo
To serve the Robot RUL dashboard (`robot-rul-dashboard/`) from a second region against the live demo data:

| Setting | Value |
|---|---|
| DATA account database | `BD_INTELLIGENCE` |
| Objects to grant to `STREAMLIT_REMOTE_READER` | The two objects the dashboard reads: `BD_INTELLIGENCE.ANALYTICS.COMPONENT_HEALTH` and `BD_INTELLIGENCE.RAW.ROBOTS` |
| `REMOTE_DATABASE` in `spec.yaml` | `BD_INTELLIGENCE` |
| Warehouse | A dedicated XSMALL `STREAMLIT_REMOTE_WH` rather than `BOSTON_DYNAMICS_WH`, so remote app cost is tracked separately |

The dashboard's queries would need to move from its `st.connection("snowflake")` session to the `run_query()` helper in section 5.3.

## 12. Alternatives (for comparison)
- **Database replication / failover groups** – local reads in east4, scheduled refresh.
- **Private listing with cross-cloud auto-fulfillment** – managed replication via listings.
- **Iceberg tables on shared GCS bucket** – single copy, cross-region reads.

---
*Disclaimer: Code samples are illustrative. Review and test with your engineering tooling before production deployment; confirm feature availability and syntax in current Snowflake documentation.*
