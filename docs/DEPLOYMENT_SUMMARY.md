<img src="Snowflake_Logo.svg" width="200">

# Boston Dynamics Intelligence Agent — Deployment Summary

**Project:** Boston Dynamics Snowflake Intelligence Agent + Customer 360  
**Date:** October 2026  
**Status:** Deployed and verified on account AWS161 (see [BUILD_LOG.md](../BUILD_LOG.md))

---

## Architecture

![Architecture](images/architecture.svg)

---

## Customer 360

![Customer 360](images/customer_360.svg)

---

## Deployment Flow

![Deployment Flow](images/deployment_flow.svg)

---

## ML Pipeline

![ML Models](images/ml_models.svg)

---

## What Was Built

### Database: `BD_INTELLIGENCE`

| Schema | Purpose |
|--------|---------|
| `RAW` | 17 tables: 9 fleet + 8 Customer 360 (~207K rows) |
| `ANALYTICS` | 16 views, `CUSTOMER_ML_SCORES` table, 10 semantic views, 6 Cortex Search services, 11 agent UDFs |
| `ML` | Snowflake Model Registry: 5 models (V1) |

### Tables (RAW Schema)

| Table | Rows | Description |
|-------|------|-------------|
| CUSTOMERS | 100 | Accounts: segment, revenue, employees, CSM, HQ city, lifecycle stage |
| DEPLOYMENTS | 200 | Customer sites |
| ROBOTS | 600 | Atlas, Spot, Stretch fleet |
| COMPONENTS | 3,000 | Component lifecycle, status, inspection RUL |
| ROBOT_TELEMETRY | 150,000 | Sensor readings over 12 months |
| MAINTENANCE_RECORDS | 6,000 | Service history with costs and durations |
| INCIDENTS | 1,382 | Severity, downtime, root cause, resolution |
| KNOWLEDGE_BASE | 25 | Technical articles + 5 Customer Success playbooks |
| FIRMWARE_RELEASES | 30 | Firmware history |
| CONTACTS | 400 | Customer stakeholders |
| CONTRACTS | 219 | RaaS subscription, purchase + support, lease, expansion |
| INVOICES | 1,962 | Billing, payment dates, late payments |
| SUPPORT_TICKETS | 2,849 | Priority, SLA, resolution time, CSAT |
| SURVEYS | 1,200 | NPS / CSAT with verbatim comments |
| PRODUCT_USAGE_DAILY | 36,500 | Daily active robots, utilization, missions, autonomy |
| OPPORTUNITIES | 356 | Renewal, upsell, new site and services pipeline |
| INTERACTIONS | 2,567 | QBRs, calls, emails, site visits with notes and sentiment |

### Analytical Views (ANALYTICS Schema)

| View | Purpose |
|------|---------|
| FLEET_OVERVIEW | Robot fleet with deployment and component health |
| TELEMETRY_DAILY_SUMMARY | Daily aggregated telemetry per robot |
| MAINTENANCE_ANALYSIS | Maintenance cost and frequency analytics |
| MAINTENANCE_MONTHLY_TREND | Monthly maintenance trends by site and customer |
| INCIDENT_DASHBOARD | Incident severity and downtime analysis |
| COMPONENT_HEALTH | Component lifecycle, risk and inspection RUL |
| CUSTOMER_FLEET_SUMMARY | Per-customer fleet overview |
| ROBOT_MODEL_PERFORMANCE | Cross-model performance comparison |
| DEPLOYMENT_PERFORMANCE | Per-site deployment metrics |
| CUSTOMER_360 | One row per customer, 78 columns, ML scores joined in |
| CUSTOMER_ML_FEATURES | Point-in-time monthly snapshots with 180-day forward labels |
| CUSTOMER_REVENUE_MONTHLY | Monthly billing and collections |
| SUPPORT_TICKET_ANALYSIS | Tickets with SLA and CSAT |
| CUSTOMER_USAGE_TREND | Monthly adoption per customer |
| SALES_PIPELINE | Opportunities with stage and outcome |
| CUSTOMER_SURVEY_RESULTS | NPS / CSAT responses |

### Semantic Views (Cortex Analyst)

| Semantic View | Source | Enables |
|---------------|--------|---------|
| BD_FLEET_OPERATIONS_SV | FLEET_OVERVIEW | Fleet status, deployments, customers |
| BD_TELEMETRY_ANALYTICS_SV | TELEMETRY_DAILY_SUMMARY | Sensor data, performance metrics |
| BD_MAINTENANCE_INTELLIGENCE_SV | MAINTENANCE_ANALYSIS | Maintenance costs, scheduling |
| BD_MAINTENANCE_TRENDS_SV | MAINTENANCE_MONTHLY_TREND | Monthly maintenance trends |
| BD_INCIDENT_ANALYSIS_SV | INCIDENT_DASHBOARD | Incident tracking, downtime |
| BD_CUSTOMER_360_SV | CUSTOMER_360 + CUSTOMER_SURVEY_RESULTS | Account health, ARR, renewals, ML scores, NPS |
| BD_REVENUE_SV | CUSTOMER_REVENUE_MONTHLY | Billing and collections by month |
| BD_SUPPORT_SV | SUPPORT_TICKET_ANALYSIS | Ticket volume, SLA, resolution, CSAT |
| BD_PIPELINE_SV | SALES_PIPELINE | Opportunities, stages, win rates |
| BD_PRODUCT_USAGE_SV | CUSTOMER_USAGE_TREND | Monthly adoption trends |

### Cortex Search Services (all ACTIVE)

| Service | Rows indexed | Description |
|---------|------|-------------|
| BD_KNOWLEDGE_SEARCH | 25 | Technical articles and Customer Success playbooks |
| BD_MAINTENANCE_SEARCH | 6,000 | Maintenance event descriptions |
| BD_INCIDENT_SEARCH | 1,382 | Incident descriptions and resolutions |
| BD_INTERACTION_SEARCH | 2,567 | QBR, call, email and site visit notes |
| BD_SUPPORT_TICKET_SEARCH | 2,849 | Support ticket subjects and descriptions |
| BD_CUSTOMER_FEEDBACK_SEARCH | 1,200 | NPS / CSAT verbatims |

### Agent Functions (SQL UDFs)

| Function | Returns | Purpose |
|----------|---------|---------|
| AGENT_GET_FLEET_HEALTH() | OBJECT | Overall fleet health summary with health score |
| AGENT_GET_ANOMALY_SUMMARY() | ARRAY | Anomalous telemetry readings |
| AGENT_GET_PREDICTIVE_MAINTENANCE() | ARRAY | Components predicted to need service |
| AGENT_GET_MAINTENANCE_COST_SUMMARY() | OBJECT | Maintenance spending breakdown |
| AGENT_GET_INCIDENT_REPORT() | OBJECT | Active incident summary |
| AGENT_GET_RUL_ESTIMATES() | ARRAY | Remaining useful life estimates |
| AGENT_GET_CUSTOMER_360(name) | OBJECT | One-account brief (ILIKE name match) |
| AGENT_GET_CHURN_RISK_LIST() | ARRAY | Accounts ranked by churn risk with drivers |
| AGENT_GET_EXPANSION_OPPORTUNITIES() | ARRAY | Accounts ranked by expansion propensity |
| AGENT_GET_RENEWAL_CALENDAR(days_ahead) | ARRAY | Renewals due within N days |
| AGENT_GET_ACCOUNT_HEALTH_SUMMARY() | OBJECT | Book-of-business health and ARR at risk |

The fixes also covered a pre-existing bug: `AGENT_GET_MAINTENANCE_COST_SUMMARY` and `AGENT_GET_INCIDENT_REPORT` used nested aggregates and failed at runtime. They now aggregate in subqueries.

### ML Models (BD_INTELLIGENCE.ML, version V1)

| Model | Type | Target | Metric |
|-------|------|--------|--------|
| BD_PREDICTIVE_MAINTENANCE | Random Forest Classifier | Component needs attention | Test AUC 0.969 |
| BD_REMAINING_USEFUL_LIFE | Gradient Boosting Regressor | Inspection RUL days | R² 0.952, MAE 198 days |
| BD_CHURN_RISK | XGBoost Classifier | Churn in next 180 days | Grouped-CV AUC 1.000 |
| BD_CUSTOMER_HEALTH_SCORE | XGBoost Regressor | Health 0-100 | R² 0.963, MAE 2.1 |
| BD_EXPANSION_PROPENSITY | XGBoost Classifier | Expansion win in next 180 days | Grouped-CV AUC 0.816 |
| Anomaly Detection | Z-Score (in notebook) | Abnormal telemetry | 7.9% of robot-days flagged |

Scores are in `ANALYTICS.CUSTOMER_ML_SCORES` (100 rows): 20 accounts scored High churn risk (all 10 churned plus all 10 active at-risk accounts, with 0 healthy accounts flagged). All 20 expanding accounts scored High expansion. **These metrics are optimistic because the synthetic signals are clean.**

---

## Agent Configuration

- **Name:** `SNOWFLAKE_INTELLIGENCE.AGENTS.BOSTON_DYNAMICS_AGENT`
- **Tools:** 27 total (10 Cortex Analyst + 6 Cortex Search + 11 Custom UDFs), 12 sample questions
- **Warehouse:** `BOSTON_DYNAMICS_WH` (X-SMALL, auto-suspend 300s)
- **Access:** Granted to PUBLIC role
- **Verified:** `DESCRIBE AGENT` shows 27 tools / 27 resources; `scripts/test_agent.py` passed 10/10 Customer 360 questions

Current book of business (from `AGENT_GET_ACCOUNT_HEALTH_SUMMARY`): 90 active customers, $50.9M ARR, $5.15M ARR at high churn risk, 18 renewals in the next 90 days.

---

## Files

```
/
├── README.md
├── BUILD_LOG.md
├── docs/
│   ├── AGENT_SETUP.md
│   ├── DEPLOYMENT_SUMMARY.md
│   ├── questions.md                 # 65 questions (45 fleet + 20 Customer 360)
│   └── images/
│       ├── architecture.svg
│       ├── customer_360.svg
│       ├── agent_tool_decision.svg
│       ├── deployment_flow.svg
│       └── ml_models.svg
├── notebooks/
│   ├── 07_ml_models.ipynb
│   └── 07_ml_models.py
├── robot-rul-dashboard/             # Streamlit app (warehouse BOSTON_DYNAMICS_WH)
├── scripts/
│   ├── deploy.py
│   ├── test_agent.py
│   ├── build_notebook.py
│   └── check_svg.py
└── sql/
    ├── setup/01_database_and_schema.sql, 02_create_tables.sql
    ├── data/03_generate_synthetic_data.sql
    ├── views/04_create_views.sql, 05_create_semantic_views.sql
    ├── search/06_create_cortex_search.sql
    ├── models/08_ml_model_functions.sql
    └── agent/09_create_agent.sql
```

---

## Execution Order

| Step | File | Notes |
|------|------|-------|
| 1 | `sql/setup/01_database_and_schema.sql` | ~1 second |
| 2 | `sql/setup/02_create_tables.sql` | ~8 seconds |
| 3 | `sql/data/03_generate_synthetic_data.sql` | Run as one session (temp tables); rerunnable |
| 4 | `sql/views/04_create_views.sql` | |
| 5 | `sql/views/05_create_semantic_views.sql` | |
| 6 | `sql/search/06_create_cortex_search.sql` | Plus indexing; rerun after recreating tables |
| 7 | `notebooks/07_ml_models.ipynb` | Required for Customer 360 scores |
| 8 | `sql/models/08_ml_model_functions.sql` | |
| 9 | `sql/agent/09_create_agent.sql` | |
