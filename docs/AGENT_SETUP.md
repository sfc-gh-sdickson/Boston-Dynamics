<img src="Snowflake_Logo.svg" width="200">

# Boston Dynamics Intelligence Agent — Setup Guide

This document provides step-by-step instructions for deploying the Boston Dynamics Intelligence Agent, including Customer 360, on Snowflake.

---

## Prerequisites

- Snowflake account with `SYSADMIN` (or equivalent) role access
- Warehouse creation privileges
- Cortex features enabled on your Snowflake account (Cortex Analyst, Cortex Search, Cortex Agents) and the Snowflake Model Registry
- SQL client (SnowSQL, Snowsight, or VS Code with Snowflake extension), or Python 3.11 with `snowflake-connector-python` for `scripts/deploy.py`
- For step 7 run locally: `snowflake-ml-python`, `xgboost`, `scikit-learn`

---

## Architecture Overview

![Architecture](images/architecture.svg)

The agent (27 tools) uses four tool categories:
- **Cortex Analyst (Text-to-SQL)**: 10 semantic views (5 fleet, 5 Customer 360)
- **Cortex Search (RAG)**: 6 services: knowledge base, maintenance, incidents, customer interactions, support tickets, customer feedback
- **Custom UDFs**: 11 agent functions (6 fleet, 5 Customer 360)
- **ML Models**: 5 registered models (predictive maintenance, RUL, churn risk, health score, expansion propensity) plus Z-score anomaly detection

![Customer 360](images/customer_360.svg)

---

## Deployment Flow

![Deployment Flow](images/deployment_flow.svg)

Fastest path:

```bash
python3 scripts/deploy.py --connection AWS161        # steps 1-6, 8, 9
python3 notebooks/07_ml_models.py                     # step 7 (or run the notebook in Snowflake)
python3 scripts/deploy.py --connection AWS161 --steps 9
```

`deploy.py` runs each SQL file in a single session, which step 3 requires because it uses temporary tables.

---

## Step-by-Step Deployment

### Step 1: Database & Schema Setup

```sql
-- Execute: sql/setup/01_database_and_schema.sql
-- Creates: BD_INTELLIGENCE database, RAW and ANALYTICS schemas, BOSTON_DYNAMICS_WH warehouse
--          (the ML schema for the Model Registry is created by step 7)
```

Verify:
```sql
SHOW SCHEMAS IN DATABASE BD_INTELLIGENCE;
SHOW WAREHOUSES LIKE 'BOSTON_DYNAMICS_WH';
```

### Step 2: Create Tables

```sql
-- Execute: sql/setup/02_create_tables.sql
-- Creates 17 tables:
--   Fleet (9):        CUSTOMERS, DEPLOYMENTS, ROBOTS, COMPONENTS, ROBOT_TELEMETRY,
--                     MAINTENANCE_RECORDS, INCIDENTS, KNOWLEDGE_BASE, FIRMWARE_RELEASES
--   Customer 360 (8): CONTACTS, CONTRACTS, INVOICES, SUPPORT_TICKETS, SURVEYS,
--                     PRODUCT_USAGE_DAILY, OPPORTUNITIES, INTERACTIONS
```

Verify:
```sql
SHOW TABLES IN SCHEMA BD_INTELLIGENCE.RAW;
```

### Step 3: Generate Synthetic Data

```sql
-- Execute: sql/data/03_generate_synthetic_data.sql   (run as ONE session: it uses temp tables)
-- Generates ~207,000 rows. Truncates all tables first, so it is safe to rerun.
```

Verify:
```sql
SELECT table_name, row_count FROM BD_INTELLIGENCE.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'RAW' ORDER BY table_name;
```

Expected counts:
| Table | Rows | Table | Rows |
|-------|------|-------|------|
| CUSTOMERS | 100 | CONTACTS | 400 |
| DEPLOYMENTS | 200 | CONTRACTS | 219 |
| ROBOTS | 600 | INVOICES | 1,962 |
| COMPONENTS | 3,000 | SUPPORT_TICKETS | 2,849 |
| ROBOT_TELEMETRY | 150,000 | SURVEYS | 1,200 |
| MAINTENANCE_RECORDS | 6,000 | PRODUCT_USAGE_DAILY | 36,500 |
| INCIDENTS | 1,382 | OPPORTUNITIES | 356 |
| KNOWLEDGE_BASE | 25 | INTERACTIONS | 2,567 |
| FIRMWARE_RELEASES | 30 | | |

Counts for profile-weighted tables (incidents, tickets, invoices, interactions, opportunities) are from the reference run.

### Step 4: Create Analytical Views

```sql
-- Execute: sql/views/04_create_views.sql
-- Creates: 16 views in ANALYTICS (9 fleet + CUSTOMER_360, CUSTOMER_ML_FEATURES,
--          CUSTOMER_REVENUE_MONTHLY, SUPPORT_TICKET_ANALYSIS, CUSTOMER_USAGE_TREND,
--          SALES_PIPELINE, CUSTOMER_SURVEY_RESULTS)
--          plus the CUSTOMER_ML_SCORES table (filled in step 7)
```

Verify:
```sql
SHOW VIEWS IN SCHEMA BD_INTELLIGENCE.ANALYTICS;
SELECT COUNT(*) FROM BD_INTELLIGENCE.ANALYTICS.CUSTOMER_360;   -- 100
```

### Step 5: Create Semantic Views

```sql
-- Execute: sql/views/05_create_semantic_views.sql
-- Creates: 10 semantic views for Cortex Analyst
--   Fleet: BD_FLEET_OPERATIONS_SV, BD_TELEMETRY_ANALYTICS_SV, BD_MAINTENANCE_INTELLIGENCE_SV,
--          BD_MAINTENANCE_TRENDS_SV, BD_INCIDENT_ANALYSIS_SV
--   C360:  BD_CUSTOMER_360_SV, BD_REVENUE_SV, BD_SUPPORT_SV, BD_PIPELINE_SV, BD_PRODUCT_USAGE_SV
```

Verify:
```sql
SHOW SEMANTIC VIEWS IN SCHEMA BD_INTELLIGENCE.ANALYTICS;
```

### Step 6: Create Cortex Search Services

```sql
-- Execute: sql/search/06_create_cortex_search.sql
-- Creates: 6 Cortex Search services
--   BD_KNOWLEDGE_SEARCH          - Technical articles + Customer Success playbooks
--   BD_MAINTENANCE_SEARCH        - Maintenance record descriptions
--   BD_INCIDENT_SEARCH           - Incident descriptions and resolutions
--   BD_INTERACTION_SEARCH        - QBR, call, email and site visit notes
--   BD_SUPPORT_TICKET_SEARCH     - Support ticket subjects and descriptions
--   BD_CUSTOMER_FEEDBACK_SEARCH  - NPS / CSAT verbatim comments
```

Verify (all should be ACTIVE):
```sql
SHOW CORTEX SEARCH SERVICES IN SCHEMA BD_INTELLIGENCE.ANALYTICS;
```

Rerun this step whenever tables are recreated (step 2), or the services stop refreshing.

### Step 7: ML Model Training (Required for Customer 360)

```
-- Execute: notebooks/07_ml_models.ipynb   (Snowflake Notebook)
--      or: python3 notebooks/07_ml_models.py  (local, connection AWS161)
-- Trains and registers to BD_INTELLIGENCE.ML (version V1):
--   BD_PREDICTIVE_MAINTENANCE, BD_REMAINING_USEFUL_LIFE,
--   BD_CHURN_RISK, BD_CUSTOMER_HEALTH_SCORE, BD_EXPANSION_PROPENSITY
-- Writes 100 rows to ANALYTICS.CUSTOMER_ML_SCORES (churn, health, expansion, SHAP drivers)
```

The Customer 360 UDFs, `BD_CUSTOMER_360_SV` and the `CUSTOMER_360` view read `CUSTOMER_ML_SCORES`. Without this step, the score columns are NULL. The fleet UDFs use threshold logic and work without it.

Verify:
```sql
SHOW MODELS IN SCHEMA BD_INTELLIGENCE.ML;                                  -- 5 models
SELECT CHURN_RISK_TIER, COUNT(*) FROM BD_INTELLIGENCE.ANALYTICS.CUSTOMER_ML_SCORES GROUP BY 1;
```

Metrics from the reference run are in the README. They are optimistic because the synthetic signals are clean.

### Step 8: Create Agent Functions

```sql
-- Execute: sql/models/08_ml_model_functions.sql
-- Creates 11 SQL UDFs exposed to the agent as custom tools:
--   Fleet: AGENT_GET_FLEET_HEALTH, AGENT_GET_ANOMALY_SUMMARY, AGENT_GET_PREDICTIVE_MAINTENANCE,
--          AGENT_GET_MAINTENANCE_COST_SUMMARY, AGENT_GET_INCIDENT_REPORT, AGENT_GET_RUL_ESTIMATES
--   C360:  AGENT_GET_CUSTOMER_360(name), AGENT_GET_CHURN_RISK_LIST, AGENT_GET_EXPANSION_OPPORTUNITIES,
--          AGENT_GET_RENEWAL_CALENDAR(days_ahead), AGENT_GET_ACCOUNT_HEALTH_SUMMARY
```

Verify:
```sql
SELECT BD_INTELLIGENCE.ANALYTICS.AGENT_GET_FLEET_HEALTH();
SELECT BD_INTELLIGENCE.ANALYTICS.AGENT_GET_CUSTOMER_360('Siemens');
SELECT BD_INTELLIGENCE.ANALYTICS.AGENT_GET_RENEWAL_CALENDAR(90);
SELECT BD_INTELLIGENCE.ANALYTICS.AGENT_GET_ACCOUNT_HEALTH_SUMMARY();
```

### Step 9: Create the Agent

```sql
-- Execute: sql/agent/09_create_agent.sql
-- Creates: BOSTON_DYNAMICS_AGENT in SNOWFLAKE_INTELLIGENCE.AGENTS (27 tools, 12 sample questions)
```

Verify:
```sql
SHOW AGENTS IN SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS;
DESC AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.BOSTON_DYNAMICS_AGENT;
```

---

## Testing the Agent

![Agent Tool Decision](images/agent_tool_decision.svg)

Run the automated check (10 Customer 360 questions through the agent):

```bash
python3 scripts/test_agent.py --connection AWS161
```

Or open **AI & ML > Snowflake Intelligence** in Snowsight and use questions from `docs/questions.md`:
1. "What is the current fleet health status?"
2. "How do I calibrate the LiDAR on a Spot robot?"
3. "Give me a 360 brief on Siemens before my renewal call."
4. "Which customers are most likely to churn, and why?"
5. "Which renewals are coming up in the next 90 days?"
6. "What are detractors saying in NPS comments?"

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Agent not visible in Snowflake Intelligence | Verify agent was created in `SNOWFLAKE_INTELLIGENCE.AGENTS` schema |
| Semantic view errors | Re-run Step 4 (views) before Step 5 (semantic views) |
| Step 3 fails on `_CUST_SEED` / temp table not found | Run the whole file in one session (use `scripts/deploy.py --steps 3`) |
| Cortex Search not returning results | Wait for indexing; if tables were recreated, rerun Step 6 |
| Churn / health / expansion scores are NULL | Run Step 7 to populate `CUSTOMER_ML_SCORES` |
| UDF errors | Verify tables have data (Step 3) and views exist (Step 4) |
| Permission denied | Grant USAGE on agent and all underlying resources to user roles |
