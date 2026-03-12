<img src="Snowflake_Logo.svg" width="200">

# Boston Dynamics — Snowflake Intelligence Agent

A complete Snowflake Intelligence architecture and implementation for Boston Dynamics, enabling natural language queries over robot fleet telemetry, maintenance records, incident data, and technical documentation.

---

## Architecture

![Architecture](docs/images/architecture.svg)

---

## Overview

Boston Dynamics is the global leader in mobile robots. This project builds a **Snowflake Intelligence Agent** that enables engineers, operations teams, fleet managers, and executives to ask natural language questions about the robot fleet — including Atlas (humanoid), Spot (quadruped), and Stretch (warehouse) platforms.

The agent combines:
- **Cortex Analyst** — Text-to-SQL over 4 semantic views for structured data queries
- **Cortex Search** — RAG-based retrieval over 80+ technical knowledge base articles
- **Custom UDFs** — 6 agent functions for fleet health, anomaly detection, predictive maintenance, cost analysis, incident reporting, and remaining useful life estimation
- **ML Models** — Predictive maintenance, anomaly detection, and RUL estimation (notebook)

---

## Quick Start

Execute SQL scripts in order (1-9) using Snowsight, SnowSQL, or any SQL client:

```bash
# Step 1: Infrastructure
sql/setup/01_database_and_schema.sql

# Step 2: Tables
sql/setup/02_create_tables.sql

# Step 3: Synthetic data
sql/data/03_generate_synthetic_data.sql

# Step 4: Analytical views
sql/views/04_create_views.sql

# Step 5: Semantic views
sql/views/05_create_semantic_views.sql

# Step 6: Cortex Search
sql/search/06_create_cortex_search.sql

# Step 7: ML models (optional)
notebooks/07_ml_models.ipynb

# Step 8: Agent functions
sql/models/08_ml_model_functions.sql

# Step 9: Create agent
sql/agent/09_create_agent.sql
```

After deployment, navigate to **AI & ML > Snowflake Intelligence** in Snowsight.

---

## Deployment Flow

![Deployment Flow](docs/images/deployment_flow.svg)

---

## Project Structure

```
/
├── README.md                              # This file
├── docs/
│   ├── AGENT_SETUP.md                    # Step-by-step setup guide
│   ├── DEPLOYMENT_SUMMARY.md             # Deployment status and inventory
│   ├── questions.md                      # 45 complex test questions
│   └── images/
│       ├── architecture.svg              # System architecture diagram
│       ├── deployment_flow.svg           # Deployment workflow diagram
│       └── ml_models.svg                # ML pipeline visualization
├── notebooks/
│   └── 07_ml_models.ipynb               # ML model training notebook
└── sql/
    ├── setup/
    │   ├── 01_database_and_schema.sql    # Database, schemas, warehouse
    │   └── 02_create_tables.sql          # 9 table definitions
    ├── data/
    │   └── 03_generate_synthetic_data.sql # ~54,000 rows synthetic data
    ├── views/
    │   ├── 04_create_views.sql           # 8 analytical views
    │   └── 05_create_semantic_views.sql  # 4 semantic views
    ├── search/
    │   └── 06_create_cortex_search.sql   # Cortex Search service
    ├── models/
    │   └── 08_ml_model_functions.sql     # 6 agent UDFs
    └── agent/
        └── 09_create_agent.sql           # Agent creation
```

---

## Data Model

### Tables (BD_INTELLIGENCE.RAW)

| Table | Rows | Description |
|-------|------|-------------|
| ROBOTS | 200 | Fleet inventory — Atlas, Spot, Stretch |
| ROBOT_TELEMETRY | 50,000 | Streaming sensor data (90 days) |
| COMPONENTS | 1,000 | Component lifecycle tracking |
| MAINTENANCE_RECORDS | 2,000 | Service history with costs |
| CUSTOMERS | 30 | Customer organizations (6 industries) |
| DEPLOYMENTS | 60 | Global deployment sites |
| INCIDENTS | 500 | Incident tracking and resolution |
| KNOWLEDGE_BASE | 80 | Technical documentation |
| FIRMWARE_RELEASES | 30 | Firmware version history |

### Semantic Views (BD_INTELLIGENCE.ANALYTICS)

| View | Covers |
|------|--------|
| BD_FLEET_OPERATIONS_SV | Robots, deployments, customers, component health |
| BD_TELEMETRY_ANALYTICS_SV | Battery, temperature, vibration, speed, errors |
| BD_MAINTENANCE_INTELLIGENCE_SV | Maintenance costs, frequency, scheduling |
| BD_INCIDENT_ANALYSIS_SV | Incidents, severity, downtime, resolution |

---

## ML Pipeline

![ML Models](docs/images/ml_models.svg)

| Model | Algorithm | Purpose |
|-------|-----------|---------|
| Predictive Maintenance | Random Forest | Component failure prediction |
| Anomaly Detection | Z-Score Statistical | Abnormal telemetry identification |
| Remaining Useful Life | Gradient Boosting | Days until component replacement |

---

## Agent Tools

The `BOSTON_DYNAMICS_AGENT` has access to 11 tools:

| Tool | Type | Purpose |
|------|------|---------|
| FleetAnalytics | Cortex Analyst | Fleet status, deployments, customers |
| TelemetryAnalytics | Cortex Analyst | Sensor data, performance metrics |
| MaintenanceAnalytics | Cortex Analyst | Maintenance costs, scheduling |
| IncidentAnalytics | Cortex Analyst | Incidents, downtime, resolution |
| KnowledgeSearch | Cortex Search | Technical docs, procedures, specs |
| GetFleetHealth | Custom UDF | Fleet health summary + score |
| GetAnomalySummary | Custom UDF | Anomalous sensor readings |
| GetPredictiveMaintenance | Custom UDF | Components needing service |
| GetMaintenanceCosts | Custom UDF | Spending breakdowns |
| GetIncidentReport | Custom UDF | Active incident summary |
| GetRULEstimates | Custom UDF | Remaining useful life predictions |

---

## Sample Questions

See [docs/questions.md](docs/questions.md) for 45 test questions. Examples:

- *"What is the current fleet health status?"*
- *"Which robots have anomalous sensor readings?"*
- *"What is the total maintenance cost by robot model?"*
- *"How do I calibrate the LiDAR sensor on Spot?"*
- *"Which components need replacement within 30 days?"*

---

## Prerequisites

- Snowflake account with SYSADMIN role
- Cortex features enabled (Analyst, Search, Agents)
- X-SMALL warehouse or larger

---

## Documentation

- [Agent Setup Guide](docs/AGENT_SETUP.md) — Step-by-step deployment instructions
- [Deployment Summary](docs/DEPLOYMENT_SUMMARY.md) — Complete inventory of deployed objects
- [Test Questions](docs/questions.md) — 45 complex validation questions
