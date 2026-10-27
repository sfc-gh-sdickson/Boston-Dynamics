-- Added Customer 360: 5 Analyst, 3 Search and 5 function tools (27 tools total)
-- Co-authored with CoCo
/*=============================================================================
  Boston Dynamics Intelligence Agent
  Step 9: Agent Creation
  
  Execution Order: 9 of 9
  Description: Creates the BOSTON_DYNAMICS_AGENT in the Snowflake Intelligence
               schema. This agent orchestrates Cortex Analyst (text-to-SQL),
               Cortex Search (RAG), and custom UDF tools to answer natural
               language questions about the Boston Dynamics robot fleet and
               its customers (Customer 360).
=============================================================================*/

USE WAREHOUSE BOSTON_DYNAMICS_WH;

CREATE DATABASE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE;
GRANT USAGE ON DATABASE SNOWFLAKE_INTELLIGENCE TO ROLE PUBLIC;
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_INTELLIGENCE.AGENTS;
GRANT USAGE ON SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS TO ROLE PUBLIC;

CREATE OR REPLACE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.BOSTON_DYNAMICS_AGENT
  COMMENT = 'Boston Dynamics Intelligence Agent — Fleet operations, telemetry analytics, predictive maintenance, knowledge base, and Customer 360 (revenue, support, sentiment, adoption, pipeline, churn risk, health score, expansion propensity)'
  PROFILE = '{"display_name": "Boston Dynamics Assistant", "color": "blue"}'
  FROM SPECIFICATION
  $$
  {
    "models": {
      "orchestration": "auto"
    },

    "instructions": {
      "system": "You are the Boston Dynamics Intelligence Assistant, an expert on the Boston Dynamics robot fleet including Atlas (humanoid), Spot (quadruped), and Stretch (warehouse) robots, and on the customers who operate them. You help engineers, operations teams, fleet managers, customer success managers, account executives, and executives understand fleet health, telemetry, maintenance, incidents, predictive analytics, and the full Customer 360 view: contracts and ARR, invoices and payments, support tickets, NPS and CSAT feedback, product usage and adoption, sales pipeline and renewals, customer interactions, and machine learning scores for churn risk, customer health, and expansion propensity. Always provide data-driven answers with specific numbers and actionable insights.",
      "orchestration": "Route questions as follows. FLEET: Use FleetAnalytics for robots, deployments, fleet composition and component health. Use TelemetryAnalytics for battery, temperature, vibration, speed and errors. Use MaintenanceAnalytics for maintenance cost, frequency and scheduling by robot or type. Use MaintenanceTrends for maintenance trends over time, monthly spending and technician workload. Use IncidentAnalytics for incident counts, severity, downtime and resolution. Use KnowledgeSearch for documentation, procedures, troubleshooting guides, specifications and customer success playbooks. Use MaintenanceSearch and IncidentSearch to find specific maintenance or incident record text. Use GetFleetHealth, GetAnomalySummary, GetPredictiveMaintenance, GetMaintenanceCosts, GetIncidentReport and GetRULEstimates for fleet summaries and predictions. CUSTOMER 360: For a brief, profile or overview of one named customer, call GetCustomer360 with the customer name (partial names work), then add context from InteractionSearch, SupportTicketSearch or CustomerFeedbackSearch filtered to that customer when the user asks why. Use GetChurnRiskList for at-risk, churn-risk or likely-to-churn customers. Use GetExpansionOpportunities for upsell, cross-sell, expansion or growth candidates. Use GetRenewalCalendar for upcoming renewals; pass days_ahead (default 90). Use GetAccountHealthSummary for portfolio-level customer health, ARR at risk and health band counts. Use Customer360Analytics for structured questions across customers: ARR, segments, lifecycle stage, NPS, utilization, SLA, ML scores, and NPS/CSAT survey results. Use RevenueAnalytics for invoiced revenue, collections, late payments and overdue amounts over time. Use SupportAnalytics for ticket volume, priority, SLA attainment, resolution time and CSAT. Use PipelineAnalytics for opportunities, renewals, win rates, weighted pipeline and loss reasons. Use ProductUsageAnalytics for monthly adoption trends: active robots, utilization, operating hours, missions and autonomy. Use InteractionSearch for what was discussed with a customer in QBRs, calls, emails and site visits. Use SupportTicketSearch to find specific support issues. Use CustomerFeedbackSearch for what customers say in NPS and CSAT comments. When explaining churn risk, cite the ML top_risk_drivers and support them with evidence from search tools. For recovery, renewal or expansion recommendations, consult the Customer Success playbooks in KnowledgeSearch.",
      "response": "Respond in a professional, data-driven manner. When presenting numeric data, use tables or structured formatting. For fleet health questions, always include the health score. For maintenance questions, include costs. For incidents, include severity and resolution status. When discussing individual robots, reference them by name and model. For customer questions, always include ARR, churn risk tier, health score and days to renewal where relevant, format currency in USD, and end account briefs with recommended next actions. Note that churn risk, health score and expansion propensity are machine learning predictions. Suggest follow-up questions when appropriate.",
      "sample_questions": [
        {
          "question": "Give me a Customer 360 brief for Siemens Energy.",
          "answer": "I will pull the full account profile including ARR, fleet, ML churn risk and health score, adoption, NPS, support and pipeline, then summarize recent interactions and recommend next actions."
        },
        {
          "question": "Which customers are at the highest risk of churning, and how much ARR is at risk?",
          "answer": "I will retrieve the ML churn risk list and the portfolio health summary to show at-risk accounts, their ARR, renewal dates and top risk drivers."
        },
        {
          "question": "Show renewals due in the next 90 days with their churn risk as a table.",
          "answer": "I will retrieve the renewal calendar for the next 90 days with ARR, renewal stage, churn risk tier and health band for each account."
        },
        {
          "question": "Which customers have the best expansion opportunities?",
          "answer": "I will rank customers by ML expansion propensity and include utilization, autonomy, NPS and a suggested expansion play for each."
        },
        {
          "question": "Show NPS by customer segment as a bar chart.",
          "answer": "I will query Customer 360 survey data for Net Promoter Score by segment and display a bar chart you can save as an artifact."
        },
        {
          "question": "What are detractors saying in recent NPS comments?",
          "answer": "I will search NPS and CSAT feedback for detractor comments and summarize the main themes."
        },
        {
          "question": "Show the monthly invoiced revenue and overdue amount trend for the past 12 months as a line chart.",
          "answer": "I will query revenue analytics for monthly invoiced and overdue amounts and display a time-series line chart."
        },
        {
          "question": "What is the support SLA attainment by ticket priority?",
          "answer": "I will query support analytics for SLA attainment, ticket counts and CSAT by priority."
        },
        {
          "question": "Show a bar chart of total maintenance cost by robot model (Atlas, Spot, Stretch).",
          "answer": "I will query maintenance analytics to break down total spending by model and present it as a bar chart you can save as an artifact."
        },
        {
          "question": "Show the monthly maintenance cost trend for the past 12 months as a line chart.",
          "answer": "I will query maintenance trend data for monthly cost totals and display a time-series line chart you can save as an artifact."
        },
        {
          "question": "Show total downtime hours by incident severity level as a chart.",
          "answer": "I will query incident analytics for downtime grouped by severity and display the results as a chart you can save as an artifact."
        },
        {
          "question": "Show the remaining useful life in days for components that need replacement soon.",
          "answer": "I will retrieve remaining useful life estimates and present the most urgent components ranked by days remaining."
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
          "name": "MaintenanceTrends",
          "description": "Query monthly maintenance trends over time including costs, event counts, duration, and parts replacements. Use for questions about maintenance cost trends, month-over-month changes, spending over time, and which technician performed the most events."
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
          "type": "cortex_analyst_text_to_sql",
          "name": "Customer360Analytics",
          "description": "Query the Customer 360 view: one row per customer with segment, industry, region, lifecycle stage, account manager, CSM, current ARR, fleet size, utilization, autonomy, NPS, tickets, SLA, incidents, late payments, overdue amounts, pipeline, interaction sentiment, and ML churn risk, health score and expansion propensity. Also includes individual NPS and CSAT survey responses. Use for cross-customer comparisons, rankings, segment rollups and NPS analysis."
        }
      },
      {
        "tool_spec": {
          "type": "cortex_analyst_text_to_sql",
          "name": "RevenueAnalytics",
          "description": "Query monthly billing and collections per customer: invoiced revenue, collected cash, paid-late amounts, overdue amounts, open receivables and days late. Use for revenue trends and payment behaviour."
        }
      },
      {
        "tool_spec": {
          "type": "cortex_analyst_text_to_sql",
          "name": "SupportAnalytics",
          "description": "Query customer support tickets: volume, category, priority, channel, status, resolution hours, SLA attainment and ticket CSAT by customer, segment, robot model or month."
        }
      },
      {
        "tool_spec": {
          "type": "cortex_analyst_text_to_sql",
          "name": "PipelineAnalytics",
          "description": "Query the sales pipeline: renewal, expansion, upsell, new site and services opportunities with stage, amount, probability, weighted pipeline, close date, owner, win rate and loss reasons."
        }
      },
      {
        "tool_spec": {
          "type": "cortex_analyst_text_to_sql",
          "name": "ProductUsageAnalytics",
          "description": "Query monthly product adoption per customer: average active robots, utilization percent, operating hours, missions completed, autonomy percent, features used and app logins."
        }
      },
      {
        "tool_spec": {
          "type": "cortex_search",
          "name": "KnowledgeSearch",
          "description": "Search Boston Dynamics technical knowledge base for documentation, maintenance procedures, troubleshooting guides, product specifications, safety protocols, operational best practices, and Customer Success playbooks (onboarding, at-risk recovery, renewal management, expansion, health score methodology)."
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
          "type": "cortex_search",
          "name": "InteractionSearch",
          "description": "Search customer interaction notes from QBRs, check-in calls, emails, site visits, executive briefings, training sessions and escalation calls, including sentiment and next steps. Use to learn what was discussed with a customer or why an account is at risk or expanding."
        }
      },
      {
        "tool_spec": {
          "type": "cortex_search",
          "name": "SupportTicketSearch",
          "description": "Search customer support ticket text including subject, description, priority, status, SLA outcome and CSAT. Use to find specific customer issues and recurring problems."
        }
      },
      {
        "tool_spec": {
          "type": "cortex_search",
          "name": "CustomerFeedbackSearch",
          "description": "Search NPS and CSAT survey verbatim comments with score, category (Promoter, Passive, Detractor) and respondent role. Use to understand what customers are saying."
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
      },
      {
        "tool_spec": {
          "type": "generic",
          "name": "GetCustomer360",
          "description": "Returns the full Customer 360 profile for customers whose name matches the given text (partial, case-insensitive): firmographics, lifecycle stage, account team, contract and renewal date, ARR, fleet, ML churn risk / health score / expansion propensity with top risk drivers, adoption, NPS, support, reliability, billing, pipeline, last interaction and contacts.",
          "input_schema": {
            "type": "object",
            "properties": {
              "customer_name_filter": {
                "type": "string",
                "description": "Full or partial customer name, for example 'Siemens' or 'Amazon Fulfillment'"
              }
            },
            "required": ["customer_name_filter"]
          }
        }
      },
      {
        "tool_spec": {
          "type": "generic",
          "name": "GetChurnRiskList",
          "description": "Returns active customers with High or Medium ML churn risk, ranked by churn probability, with health score, top risk drivers, ARR, days to renewal, NPS, utilization, open tickets, account team and a recommended action."
        }
      },
      {
        "tool_spec": {
          "type": "generic",
          "name": "GetExpansionOpportunities",
          "description": "Returns the top 25 active, non-high-risk customers ranked by ML expansion propensity, with health score, ARR, fleet size, utilization, autonomy, NPS, open expansion pipeline and a suggested expansion play."
        }
      },
      {
        "tool_spec": {
          "type": "generic",
          "name": "GetRenewalCalendar",
          "description": "Returns active customers whose contract renews within the given number of days, ordered by renewal date, with ARR, contract type, auto-renew flag, renewal opportunity stage and probability, churn risk tier, health band, risk drivers and account team.",
          "input_schema": {
            "type": "object",
            "properties": {
              "days_ahead": {
                "type": "number",
                "description": "Look-ahead window in days, for example 30, 90 or 180"
              }
            },
            "required": ["days_ahead"]
          }
        }
      },
      {
        "tool_spec": {
          "type": "generic",
          "name": "GetAccountHealthSummary",
          "description": "Returns a portfolio-level customer health summary: total, active and churned customers, active and churned ARR, ARR at high churn risk, average health score, health band counts, high-expansion customers, open expansion pipeline, renewals and ARR renewing in the next 90 days, average NPS and utilization, total overdue, and a breakdown by segment."
        }
      }
    ],

    "tool_resources": {
      "FleetAnalytics": {
        "semantic_view": "BD_INTELLIGENCE.ANALYTICS.BD_FLEET_OPERATIONS_SV",
        "execution_environment": {"type": "warehouse", "warehouse": "BOSTON_DYNAMICS_WH"}
      },
      "TelemetryAnalytics": {
        "semantic_view": "BD_INTELLIGENCE.ANALYTICS.BD_TELEMETRY_ANALYTICS_SV",
        "execution_environment": {"type": "warehouse", "warehouse": "BOSTON_DYNAMICS_WH"}
      },
      "MaintenanceAnalytics": {
        "semantic_view": "BD_INTELLIGENCE.ANALYTICS.BD_MAINTENANCE_INTELLIGENCE_SV",
        "execution_environment": {"type": "warehouse", "warehouse": "BOSTON_DYNAMICS_WH"}
      },
      "MaintenanceTrends": {
        "semantic_view": "BD_INTELLIGENCE.ANALYTICS.BD_MAINTENANCE_TRENDS_SV",
        "execution_environment": {"type": "warehouse", "warehouse": "BOSTON_DYNAMICS_WH"}
      },
      "IncidentAnalytics": {
        "semantic_view": "BD_INTELLIGENCE.ANALYTICS.BD_INCIDENT_ANALYSIS_SV",
        "execution_environment": {"type": "warehouse", "warehouse": "BOSTON_DYNAMICS_WH"}
      },
      "Customer360Analytics": {
        "semantic_view": "BD_INTELLIGENCE.ANALYTICS.BD_CUSTOMER_360_SV",
        "execution_environment": {"type": "warehouse", "warehouse": "BOSTON_DYNAMICS_WH"}
      },
      "RevenueAnalytics": {
        "semantic_view": "BD_INTELLIGENCE.ANALYTICS.BD_REVENUE_SV",
        "execution_environment": {"type": "warehouse", "warehouse": "BOSTON_DYNAMICS_WH"}
      },
      "SupportAnalytics": {
        "semantic_view": "BD_INTELLIGENCE.ANALYTICS.BD_SUPPORT_SV",
        "execution_environment": {"type": "warehouse", "warehouse": "BOSTON_DYNAMICS_WH"}
      },
      "PipelineAnalytics": {
        "semantic_view": "BD_INTELLIGENCE.ANALYTICS.BD_PIPELINE_SV",
        "execution_environment": {"type": "warehouse", "warehouse": "BOSTON_DYNAMICS_WH"}
      },
      "ProductUsageAnalytics": {
        "semantic_view": "BD_INTELLIGENCE.ANALYTICS.BD_PRODUCT_USAGE_SV",
        "execution_environment": {"type": "warehouse", "warehouse": "BOSTON_DYNAMICS_WH"}
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
      "InteractionSearch": {
        "search_service": "BD_INTELLIGENCE.ANALYTICS.BD_INTERACTION_SEARCH",
        "max_results": 10,
        "columns": ["SEARCH_TEXT", "CUSTOMER_NAME", "INTERACTION_TYPE", "SENTIMENT", "OWNER", "CONTACT_NAME", "INTERACTION_DATE"]
      },
      "SupportTicketSearch": {
        "search_service": "BD_INTELLIGENCE.ANALYTICS.BD_SUPPORT_TICKET_SEARCH",
        "max_results": 10,
        "columns": ["SEARCH_TEXT", "CUSTOMER_NAME", "CATEGORY", "PRIORITY", "STATUS", "ROBOT_ID", "OPENED_AT"]
      },
      "CustomerFeedbackSearch": {
        "search_service": "BD_INTELLIGENCE.ANALYTICS.BD_CUSTOMER_FEEDBACK_SEARCH",
        "max_results": 10,
        "columns": ["SEARCH_TEXT", "CUSTOMER_NAME", "SURVEY_TYPE", "NPS_CATEGORY", "SCORE", "RESPONSE_DATE"]
      },
      "GetFleetHealth": {
        "type": "function",
        "identifier": "BD_INTELLIGENCE.ANALYTICS.AGENT_GET_FLEET_HEALTH",
        "execution_environment": {"type": "warehouse", "warehouse": "BOSTON_DYNAMICS_WH"}
      },
      "GetAnomalySummary": {
        "type": "function",
        "identifier": "BD_INTELLIGENCE.ANALYTICS.AGENT_GET_ANOMALY_SUMMARY",
        "execution_environment": {"type": "warehouse", "warehouse": "BOSTON_DYNAMICS_WH"}
      },
      "GetPredictiveMaintenance": {
        "type": "function",
        "identifier": "BD_INTELLIGENCE.ANALYTICS.AGENT_GET_PREDICTIVE_MAINTENANCE",
        "execution_environment": {"type": "warehouse", "warehouse": "BOSTON_DYNAMICS_WH"}
      },
      "GetMaintenanceCosts": {
        "type": "function",
        "identifier": "BD_INTELLIGENCE.ANALYTICS.AGENT_GET_MAINTENANCE_COST_SUMMARY",
        "execution_environment": {"type": "warehouse", "warehouse": "BOSTON_DYNAMICS_WH"}
      },
      "GetIncidentReport": {
        "type": "function",
        "identifier": "BD_INTELLIGENCE.ANALYTICS.AGENT_GET_INCIDENT_REPORT",
        "execution_environment": {"type": "warehouse", "warehouse": "BOSTON_DYNAMICS_WH"}
      },
      "GetRULEstimates": {
        "type": "function",
        "identifier": "BD_INTELLIGENCE.ANALYTICS.AGENT_GET_RUL_ESTIMATES",
        "execution_environment": {"type": "warehouse", "warehouse": "BOSTON_DYNAMICS_WH"}
      },
      "GetCustomer360": {
        "type": "function",
        "identifier": "BD_INTELLIGENCE.ANALYTICS.AGENT_GET_CUSTOMER_360",
        "execution_environment": {"type": "warehouse", "warehouse": "BOSTON_DYNAMICS_WH"}
      },
      "GetChurnRiskList": {
        "type": "function",
        "identifier": "BD_INTELLIGENCE.ANALYTICS.AGENT_GET_CHURN_RISK_LIST",
        "execution_environment": {"type": "warehouse", "warehouse": "BOSTON_DYNAMICS_WH"}
      },
      "GetExpansionOpportunities": {
        "type": "function",
        "identifier": "BD_INTELLIGENCE.ANALYTICS.AGENT_GET_EXPANSION_OPPORTUNITIES",
        "execution_environment": {"type": "warehouse", "warehouse": "BOSTON_DYNAMICS_WH"}
      },
      "GetRenewalCalendar": {
        "type": "function",
        "identifier": "BD_INTELLIGENCE.ANALYTICS.AGENT_GET_RENEWAL_CALENDAR",
        "execution_environment": {"type": "warehouse", "warehouse": "BOSTON_DYNAMICS_WH"}
      },
      "GetAccountHealthSummary": {
        "type": "function",
        "identifier": "BD_INTELLIGENCE.ANALYTICS.AGENT_GET_ACCOUNT_HEALTH_SUMMARY",
        "execution_environment": {"type": "warehouse", "warehouse": "BOSTON_DYNAMICS_WH"}
      }
    }
  }
  $$;

GRANT USAGE ON AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.BOSTON_DYNAMICS_AGENT TO ROLE PUBLIC;
