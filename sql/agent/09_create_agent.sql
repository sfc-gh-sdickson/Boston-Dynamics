/*=============================================================================
  Boston Dynamics Intelligence Agent
  Step 9: Agent Creation
  
  Execution Order: 9 of 9
  Description: Creates the BOSTON_DYNAMICS_AGENT in the Snowflake Intelligence
               schema. This agent orchestrates Cortex Analyst (text-to-SQL),
               Cortex Search (RAG), and custom UDF tools to answer natural
               language questions about the Boston Dynamics robot fleet.
=============================================================================*/

USE WAREHOUSE BOSTON_DYNAMICS_WH;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE;
GRANT USAGE ON DATABASE SNOWFLAKE_INTELLIGENCE TO ROLE PUBLIC;
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_INTELLIGENCE.AGENTS;
GRANT USAGE ON SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS TO ROLE PUBLIC;

CREATE OR REPLACE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.BOSTON_DYNAMICS_AGENT
  COMMENT = 'Boston Dynamics Intelligence Agent — Fleet operations, telemetry analytics, predictive maintenance, and knowledge base'
  PROFILE = '{"display_name": "Boston Dynamics Assistant", "color": "blue"}'
  FROM SPECIFICATION
  $$
  {
    "models": {
      "orchestration": "auto"
    },

    "instructions": {
      "system": "You are the Boston Dynamics Intelligence Assistant, an expert on the Boston Dynamics robot fleet including Atlas (humanoid), Spot (quadruped), and Stretch (warehouse) robots. You help engineers, operations teams, fleet managers, and executives understand fleet health, telemetry data, maintenance schedules, incidents, and predictive analytics. Always provide data-driven answers with specific numbers and actionable insights.",
      "orchestration": "Route questions as follows: Use FleetAnalytics for structured data questions about robots, telemetry, maintenance costs, incidents, customers, and deployments. Use TelemetryAnalytics for sensor data questions about battery, temperature, vibration, speed, and errors. Use MaintenanceAnalytics for maintenance cost, frequency, and scheduling questions. Use IncidentAnalytics for incident tracking, severity, downtime, and resolution questions. Use KnowledgeSearch for technical documentation, procedures, troubleshooting guides, and product specifications. Use MaintenanceSearch to find specific maintenance event descriptions, service notes, parts replaced, and technician outcomes by searching maintenance record text. Use IncidentSearch to find specific incident descriptions, resolutions, and root cause analyses by searching incident record text. Use GetFleetHealth for a quick overall fleet health summary. Use GetAnomalySummary for current anomalous sensor readings. Use GetPredictiveMaintenance for components predicted to need service soon. Use GetMaintenanceCosts for maintenance spending breakdowns. Use GetIncidentReport for active incident summaries. Use GetRULEstimates for remaining useful life predictions on components.",
      "response": "Respond in a professional, data-driven manner. When presenting numeric data, use tables or structured formatting. For fleet health questions, always include the health score. For maintenance questions, include costs. For incidents, include severity and resolution status. When discussing individual robots, reference them by name and model. Suggest follow-up questions when appropriate.",
      "sample_questions": [
        {
          "question": "Show me a bar chart of total maintenance cost by robot model (Atlas, Spot, Stretch).",
          "answer": "I will query maintenance analytics to break down total spending by model and present it as a bar chart you can save as an artifact."
        },
        {
          "question": "Show the monthly maintenance cost trend for the past 6 months as a line chart.",
          "answer": "I will query maintenance analytics for monthly cost totals and display a time-series line chart you can save as an artifact."
        },
        {
          "question": "What is the breakdown of robots by status (Active, Maintenance, Decommissioned)? Show as a table.",
          "answer": "I will query fleet data to show robot counts grouped by status in a table you can save as an artifact."
        },
        {
          "question": "Show total downtime hours by incident severity level as a chart.",
          "answer": "I will query incident analytics for downtime grouped by severity and display the results as a chart you can save as an artifact."
        },
        {
          "question": "Show the top 10 robots by average motor temperature over the past 30 days.",
          "answer": "I will query telemetry data for the highest average motor temperatures and present a ranked chart you can save as an artifact."
        },
        {
          "question": "Compare incident counts by robot model. Which model has the most incidents?",
          "answer": "I will query incident analytics to compare incident volume across Atlas, Spot, and Stretch models in a chart you can save as an artifact."
        },
        {
          "question": "Show the distribution of robots across deployment sites as a pie chart.",
          "answer": "I will query fleet data for robot counts per deployment site and display a pie chart showing the percentage distribution you can save as an artifact."
        },
        {
          "question": "Plot average battery level versus average motor temperature for each robot as a scatter chart.",
          "answer": "I will query telemetry data for per-robot averages and present a scatter chart so you can spot correlations and save it as an artifact."
        },
        {
          "question": "Show a stacked bar chart of maintenance events by type (Corrective, Preventive, Predictive) for each robot model.",
          "answer": "I will query maintenance analytics for event counts grouped by type and model and display a stacked bar chart you can save as an artifact."
        },
        {
          "question": "Show the remaining useful life in days for all components currently in Degraded status as a horizontal bar chart, sorted shortest to longest.",
          "answer": "I will query predictive maintenance data for degraded components and present a horizontal bar chart ranked by urgency you can save as an artifact."
        },
        {
          "question": "Show a heatmap-style table of average vibration levels by robot model and deployment site.",
          "answer": "I will query telemetry data to create a cross-tabulation of vibration by model and site, displayed as a color-coded table you can save as an artifact."
        }
      ]
    },

    "tools": [
      {
        "tool_spec": {
          "type": "cortex_analyst_text_to_sql",
          "name": "FleetAnalytics",
          "description": "Query Boston Dynamics fleet data including robot status, deployments, customers, and component health. Use for questions about how many robots, which customers, deployment sites, and fleet composition."
        }
      },
      {
        "tool_spec": {
          "type": "cortex_analyst_text_to_sql",
          "name": "TelemetryAnalytics",
          "description": "Query robot telemetry and sensor data including battery levels, CPU and motor temperatures, vibration, joint load, speed, and error rates. Use for questions about robot performance metrics over time."
        }
      },
      {
        "tool_spec": {
          "type": "cortex_analyst_text_to_sql",
          "name": "MaintenanceAnalytics",
          "description": "Query maintenance records including costs, frequency, duration, parts replacements, and scheduling. Use for questions about maintenance spending, service history, and maintenance types."
        }
      },
      {
        "tool_spec": {
          "type": "cortex_analyst_text_to_sql",
          "name": "IncidentAnalytics",
          "description": "Query incident data including incident types, severity levels, downtime, resolution status, and root causes. Use for questions about failures, outages, and safety events."
        }
      },
      {
        "tool_spec": {
          "type": "cortex_search",
          "name": "KnowledgeSearch",
          "description": "Search Boston Dynamics technical knowledge base for documentation, maintenance procedures, troubleshooting guides, product specifications, safety protocols, and operational best practices for Atlas, Spot, and Stretch robots."
        }
      },
      {
        "tool_spec": {
          "type": "cortex_search",
          "name": "MaintenanceSearch",
          "description": "Search maintenance records for specific service events, repair descriptions, parts replaced, technician notes, and maintenance outcomes across the robot fleet."
        }
      },
      {
        "tool_spec": {
          "type": "cortex_search",
          "name": "IncidentSearch",
          "description": "Search incident records for specific incident descriptions, resolution details, root cause analyses, and troubleshooting outcomes across the robot fleet."
        }
      },
      {
        "tool_spec": {
          "type": "generic",
          "name": "GetFleetHealth",
          "description": "Returns a comprehensive fleet health summary object including total robots by status, robot counts by model, component health metrics, deployment count, customer count, open incidents, and an overall fleet health score percentage."
        }
      },
      {
        "tool_spec": {
          "type": "generic",
          "name": "GetAnomalySummary",
          "description": "Returns an array of anomalous telemetry readings from the past 7 days, including high motor temperatures, excessive vibration, and low battery alerts with severity levels."
        }
      },
      {
        "tool_spec": {
          "type": "generic",
          "name": "GetPredictiveMaintenance",
          "description": "Returns an array of components predicted to need maintenance or replacement soon, ordered by risk level, including lifecycle utilization, estimated remaining days, and maintenance recommendations."
        }
      },
      {
        "tool_spec": {
          "type": "generic",
          "name": "GetMaintenanceCosts",
          "description": "Returns a maintenance cost summary object including total costs, costs by maintenance type, costs by robot model, and the top 5 costliest robots."
        }
      },
      {
        "tool_spec": {
          "type": "generic",
          "name": "GetIncidentReport",
          "description": "Returns an incident report object including open and resolved counts, critical incidents, total downtime hours, average resolution time, breakdowns by severity and type, and top root causes."
        }
      },
      {
        "tool_spec": {
          "type": "generic",
          "name": "GetRULEstimates",
          "description": "Returns remaining useful life estimates for components nearing end of life, including days remaining, runtime hours, lifecycle utilization percentage, and urgency classification."
        }
      }
    ],

    "tool_resources": {
      "FleetAnalytics": {
        "semantic_view": "BD_INTELLIGENCE.ANALYTICS.BD_FLEET_OPERATIONS_SV",
        "execution_environment": {
          "type": "warehouse",
          "warehouse": "BOSTON_DYNAMICS_WH"
        }
      },
      "TelemetryAnalytics": {
        "semantic_view": "BD_INTELLIGENCE.ANALYTICS.BD_TELEMETRY_ANALYTICS_SV",
        "execution_environment": {
          "type": "warehouse",
          "warehouse": "BOSTON_DYNAMICS_WH"
        }
      },
      "MaintenanceAnalytics": {
        "semantic_view": "BD_INTELLIGENCE.ANALYTICS.BD_MAINTENANCE_INTELLIGENCE_SV",
        "execution_environment": {
          "type": "warehouse",
          "warehouse": "BOSTON_DYNAMICS_WH"
        }
      },
      "IncidentAnalytics": {
        "semantic_view": "BD_INTELLIGENCE.ANALYTICS.BD_INCIDENT_ANALYSIS_SV",
        "execution_environment": {
          "type": "warehouse",
          "warehouse": "BOSTON_DYNAMICS_WH"
        }
      },
      "KnowledgeSearch": {
        "search_service": "BD_INTELLIGENCE.ANALYTICS.BD_KNOWLEDGE_SEARCH",
        "max_results": 10,
        "columns": ["TITLE", "CONTENT", "CATEGORY", "ROBOT_MODEL", "TAGS"]
      },
      "MaintenanceSearch": {
        "search_service": "BD_INTELLIGENCE.ANALYTICS.BD_MAINTENANCE_SEARCH",
        "max_results": 10,
        "columns": ["SEARCH_TEXT", "ROBOT_NAME", "ROBOT_MODEL", "MAINTENANCE_TYPE", "PERFORMED_BY", "OUTCOME"]
      },
      "IncidentSearch": {
        "search_service": "BD_INTELLIGENCE.ANALYTICS.BD_INCIDENT_SEARCH",
        "max_results": 10,
        "columns": ["SEARCH_TEXT", "ROBOT_NAME", "ROBOT_MODEL", "INCIDENT_TYPE", "SEVERITY", "ROOT_CAUSE"]
      },
      "GetFleetHealth": {
        "type": "function",
        "identifier": "BD_INTELLIGENCE.ANALYTICS.AGENT_GET_FLEET_HEALTH",
        "execution_environment": {
          "type": "warehouse",
          "warehouse": "BOSTON_DYNAMICS_WH"
        }
      },
      "GetAnomalySummary": {
        "type": "function",
        "identifier": "BD_INTELLIGENCE.ANALYTICS.AGENT_GET_ANOMALY_SUMMARY",
        "execution_environment": {
          "type": "warehouse",
          "warehouse": "BOSTON_DYNAMICS_WH"
        }
      },
      "GetPredictiveMaintenance": {
        "type": "function",
        "identifier": "BD_INTELLIGENCE.ANALYTICS.AGENT_GET_PREDICTIVE_MAINTENANCE",
        "execution_environment": {
          "type": "warehouse",
          "warehouse": "BOSTON_DYNAMICS_WH"
        }
      },
      "GetMaintenanceCosts": {
        "type": "function",
        "identifier": "BD_INTELLIGENCE.ANALYTICS.AGENT_GET_MAINTENANCE_COST_SUMMARY",
        "execution_environment": {
          "type": "warehouse",
          "warehouse": "BOSTON_DYNAMICS_WH"
        }
      },
      "GetIncidentReport": {
        "type": "function",
        "identifier": "BD_INTELLIGENCE.ANALYTICS.AGENT_GET_INCIDENT_REPORT",
        "execution_environment": {
          "type": "warehouse",
          "warehouse": "BOSTON_DYNAMICS_WH"
        }
      },
      "GetRULEstimates": {
        "type": "function",
        "identifier": "BD_INTELLIGENCE.ANALYTICS.AGENT_GET_RUL_ESTIMATES",
        "execution_environment": {
          "type": "warehouse",
          "warehouse": "BOSTON_DYNAMICS_WH"
        }
      }
    }
  }
  $$;

GRANT USAGE ON AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.BOSTON_DYNAMICS_AGENT TO ROLE PUBLIC;
