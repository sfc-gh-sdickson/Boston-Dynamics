/*=============================================================================
  Boston Dynamics Intelligence Agent
  Step 8: ML Model Functions (Agent UDFs)
  
  Execution Order: 8 of 9
  Description: Creates SQL UDFs that the agent uses as custom tools to
               retrieve ML predictions, fleet health summaries, anomaly
               reports, and operational insights.
=============================================================================*/

USE DATABASE BD_INTELLIGENCE;
USE SCHEMA ANALYTICS;
USE WAREHOUSE BOSTON_DYNAMICS_WH;

-- ============================================================================
-- AGENT_GET_FLEET_HEALTH: Overall fleet health summary
-- ============================================================================
CREATE OR REPLACE FUNCTION AGENT_GET_FLEET_HEALTH()
RETURNS OBJECT
AS
$$
SELECT OBJECT_CONSTRUCT(
    'total_robots', (SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.ROBOTS),
    'active_robots', (SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.ROBOTS WHERE STATUS = 'Active'),
    'idle_robots', (SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.ROBOTS WHERE STATUS = 'Idle'),
    'maintenance_robots', (SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.ROBOTS WHERE STATUS = 'Maintenance'),
    'decommissioned_robots', (SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.ROBOTS WHERE STATUS = 'Decommissioned'),
    'atlas_count', (SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.ROBOTS WHERE ROBOT_MODEL = 'Atlas'),
    'spot_count', (SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.ROBOTS WHERE ROBOT_MODEL = 'Spot'),
    'stretch_count', (SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.ROBOTS WHERE ROBOT_MODEL = 'Stretch'),
    'total_components', (SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.COMPONENTS),
    'failed_components', (SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.COMPONENTS WHERE STATUS = 'Failed'),
    'degraded_components', (SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.COMPONENTS WHERE STATUS = 'Degraded'),
    'needs_replacement', (SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.COMPONENTS WHERE STATUS = 'Needs Replacement'),
    'active_deployments', (SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.DEPLOYMENTS WHERE STATUS = 'Active'),
    'total_customers', (SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.CUSTOMERS),
    'open_incidents', (SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.INCIDENTS WHERE RESOLVED_AT IS NULL),
    'fleet_health_score', (SELECT ROUND(
        (SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.ROBOTS WHERE STATUS = 'Active') * 100.0 /
        NULLIF((SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.ROBOTS), 0), 1))
)
$$;

-- ============================================================================
-- AGENT_GET_ANOMALY_SUMMARY: Recent anomalous telemetry readings
-- ============================================================================
CREATE OR REPLACE FUNCTION AGENT_GET_ANOMALY_SUMMARY()
RETURNS ARRAY
AS
$$
SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
    'robot_id', ROBOT_ID,
    'robot_name', ROBOT_NAME,
    'robot_model', ROBOT_MODEL,
    'anomaly_type', ANOMALY_TYPE,
    'current_value', CURRENT_VALUE,
    'threshold', THRESHOLD,
    'severity', SEVERITY,
    'reading_date', READING_DATE::VARCHAR
)) FROM (
    SELECT
        t.ROBOT_ID,
        r.ROBOT_NAME,
        r.ROBOT_MODEL,
        'High Motor Temperature' AS ANOMALY_TYPE,
        ROUND(MAX(t.MOTOR_TEMPERATURE_C), 1) AS CURRENT_VALUE,
        85.0 AS THRESHOLD,
        CASE WHEN MAX(t.MOTOR_TEMPERATURE_C) > 100 THEN 'Critical' WHEN MAX(t.MOTOR_TEMPERATURE_C) > 90 THEN 'High' ELSE 'Medium' END AS SEVERITY,
        DATE_TRUNC('DAY', t.TIMESTAMP)::DATE AS READING_DATE
    FROM BD_INTELLIGENCE.RAW.ROBOT_TELEMETRY t
    JOIN BD_INTELLIGENCE.RAW.ROBOTS r ON t.ROBOT_ID = r.ROBOT_ID
    WHERE t.MOTOR_TEMPERATURE_C > 85
      AND t.TIMESTAMP > DATEADD(DAY, -7, CURRENT_TIMESTAMP())
    GROUP BY t.ROBOT_ID, r.ROBOT_NAME, r.ROBOT_MODEL, DATE_TRUNC('DAY', t.TIMESTAMP)::DATE

    UNION ALL

    SELECT
        t.ROBOT_ID,
        r.ROBOT_NAME,
        r.ROBOT_MODEL,
        'Excessive Vibration' AS ANOMALY_TYPE,
        ROUND(MAX(t.VIBRATION_MM_S), 2) AS CURRENT_VALUE,
        10.0 AS THRESHOLD,
        CASE WHEN MAX(t.VIBRATION_MM_S) > 13 THEN 'Critical' WHEN MAX(t.VIBRATION_MM_S) > 11 THEN 'High' ELSE 'Medium' END AS SEVERITY,
        DATE_TRUNC('DAY', t.TIMESTAMP)::DATE AS READING_DATE
    FROM BD_INTELLIGENCE.RAW.ROBOT_TELEMETRY t
    JOIN BD_INTELLIGENCE.RAW.ROBOTS r ON t.ROBOT_ID = r.ROBOT_ID
    WHERE t.VIBRATION_MM_S > 10
      AND t.TIMESTAMP > DATEADD(DAY, -7, CURRENT_TIMESTAMP())
    GROUP BY t.ROBOT_ID, r.ROBOT_NAME, r.ROBOT_MODEL, DATE_TRUNC('DAY', t.TIMESTAMP)::DATE

    UNION ALL

    SELECT
        t.ROBOT_ID,
        r.ROBOT_NAME,
        r.ROBOT_MODEL,
        'Low Battery' AS ANOMALY_TYPE,
        ROUND(MIN(t.BATTERY_LEVEL), 1) AS CURRENT_VALUE,
        15.0 AS THRESHOLD,
        CASE WHEN MIN(t.BATTERY_LEVEL) < 8 THEN 'Critical' WHEN MIN(t.BATTERY_LEVEL) < 12 THEN 'High' ELSE 'Medium' END AS SEVERITY,
        DATE_TRUNC('DAY', t.TIMESTAMP)::DATE AS READING_DATE
    FROM BD_INTELLIGENCE.RAW.ROBOT_TELEMETRY t
    JOIN BD_INTELLIGENCE.RAW.ROBOTS r ON t.ROBOT_ID = r.ROBOT_ID
    WHERE t.BATTERY_LEVEL < 15
      AND t.TIMESTAMP > DATEADD(DAY, -7, CURRENT_TIMESTAMP())
    GROUP BY t.ROBOT_ID, r.ROBOT_NAME, r.ROBOT_MODEL, DATE_TRUNC('DAY', t.TIMESTAMP)::DATE

    ORDER BY SEVERITY, READING_DATE DESC
    LIMIT 50
)
$$;

-- ============================================================================
-- AGENT_GET_PREDICTIVE_MAINTENANCE: Components predicted to need service
-- ============================================================================
CREATE OR REPLACE FUNCTION AGENT_GET_PREDICTIVE_MAINTENANCE()
RETURNS ARRAY
AS
$$
SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
    'component_id', COMPONENT_ID,
    'robot_id', ROBOT_ID,
    'robot_name', ROBOT_NAME,
    'robot_model', ROBOT_MODEL,
    'component_type', COMPONENT_TYPE,
    'component_name', COMPONENT_NAME,
    'component_status', COMPONENT_STATUS,
    'lifecycle_percent_used', LIFECYCLE_PERCENT_USED,
    'days_since_install', DAYS_SINCE_INSTALL,
    'expected_lifespan_days', EXPECTED_LIFESPAN_DAYS,
    'estimated_remaining_days', ESTIMATED_REMAINING_DAYS,
    'risk_level', RISK_LEVEL,
    'recommendation', RECOMMENDATION,
    'site_name', SITE_NAME,
    'customer_name', CUSTOMER_NAME
)) FROM (
    SELECT
        ch.COMPONENT_ID,
        ch.ROBOT_ID,
        ch.ROBOT_NAME,
        ch.ROBOT_MODEL,
        ch.COMPONENT_TYPE,
        ch.COMPONENT_NAME,
        ch.COMPONENT_STATUS,
        ch.LIFECYCLE_PERCENT_USED,
        ch.DAYS_SINCE_INSTALL,
        ch.EXPECTED_LIFESPAN_DAYS,
        GREATEST(ch.EXPECTED_LIFESPAN_DAYS - ch.DAYS_SINCE_INSTALL, 0) AS ESTIMATED_REMAINING_DAYS,
        ch.RISK_LEVEL,
        CASE
            WHEN ch.RISK_LEVEL = 'Critical' THEN 'Immediate replacement required'
            WHEN ch.RISK_LEVEL = 'High' THEN 'Schedule replacement within 2 weeks'
            WHEN ch.RISK_LEVEL = 'Medium' THEN 'Monitor closely, plan replacement within 30 days'
            ELSE 'Routine monitoring sufficient'
        END AS RECOMMENDATION,
        ch.SITE_NAME,
        ch.CUSTOMER_NAME
    FROM BD_INTELLIGENCE.ANALYTICS.COMPONENT_HEALTH ch
    WHERE ch.RISK_LEVEL IN ('Critical', 'High', 'Medium')
    ORDER BY
        CASE ch.RISK_LEVEL WHEN 'Critical' THEN 1 WHEN 'High' THEN 2 WHEN 'Medium' THEN 3 END,
        ch.LIFECYCLE_PERCENT_USED DESC
    LIMIT 50
)
$$;

-- ============================================================================
-- AGENT_GET_MAINTENANCE_COST_SUMMARY: Maintenance spending breakdown
-- ============================================================================
CREATE OR REPLACE FUNCTION AGENT_GET_MAINTENANCE_COST_SUMMARY()
RETURNS OBJECT
AS
$$
SELECT OBJECT_CONSTRUCT(
    'total_maintenance_cost', (SELECT ROUND(SUM(COST_USD), 2) FROM BD_INTELLIGENCE.RAW.MAINTENANCE_RECORDS),
    'avg_cost_per_event', (SELECT ROUND(AVG(COST_USD), 2) FROM BD_INTELLIGENCE.RAW.MAINTENANCE_RECORDS),
    'total_events', (SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.MAINTENANCE_RECORDS),
    'cost_by_type', (
        SELECT ARRAY_AGG(OBJECT_CONSTRUCT('type', MAINTENANCE_TYPE, 'total_cost', TOTAL_COST, 'event_count', EVENT_COUNT))
        FROM (SELECT MAINTENANCE_TYPE, ROUND(SUM(COST_USD), 2) AS TOTAL_COST, COUNT(*) AS EVENT_COUNT
              FROM BD_INTELLIGENCE.RAW.MAINTENANCE_RECORDS GROUP BY MAINTENANCE_TYPE)
    ),
    'cost_by_model', (
        SELECT ARRAY_AGG(OBJECT_CONSTRUCT('model', ROBOT_MODEL, 'total_cost', TOTAL_COST, 'event_count', EVENT_COUNT))
        FROM (SELECT r.ROBOT_MODEL, ROUND(SUM(m.COST_USD), 2) AS TOTAL_COST, COUNT(*) AS EVENT_COUNT
              FROM BD_INTELLIGENCE.RAW.MAINTENANCE_RECORDS m
              JOIN BD_INTELLIGENCE.RAW.ROBOTS r ON m.ROBOT_ID = r.ROBOT_ID
              GROUP BY r.ROBOT_MODEL)
    ),
    'top_5_costliest_robots', (
        SELECT ARRAY_AGG(OBJECT_CONSTRUCT('robot_name', ROBOT_NAME, 'robot_model', ROBOT_MODEL, 'total_cost', TOTAL_COST))
               WITHIN GROUP (ORDER BY TOTAL_COST DESC)
        FROM (SELECT r.ROBOT_NAME, r.ROBOT_MODEL, ROUND(SUM(m.COST_USD), 2) AS TOTAL_COST
              FROM BD_INTELLIGENCE.RAW.MAINTENANCE_RECORDS m
              JOIN BD_INTELLIGENCE.RAW.ROBOTS r ON m.ROBOT_ID = r.ROBOT_ID
              GROUP BY r.ROBOT_NAME, r.ROBOT_MODEL
              ORDER BY TOTAL_COST DESC
              LIMIT 5)
    )
)
$$;

-- ============================================================================
-- AGENT_GET_INCIDENT_REPORT: Active and recent incident summary
-- ============================================================================
CREATE OR REPLACE FUNCTION AGENT_GET_INCIDENT_REPORT()
RETURNS OBJECT
AS
$$
SELECT OBJECT_CONSTRUCT(
    'total_incidents', (SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.INCIDENTS),
    'open_incidents', (SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.INCIDENTS WHERE RESOLVED_AT IS NULL),
    'resolved_incidents', (SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.INCIDENTS WHERE RESOLVED_AT IS NOT NULL),
    'critical_open', (SELECT COUNT(*) FROM BD_INTELLIGENCE.RAW.INCIDENTS WHERE RESOLVED_AT IS NULL AND SEVERITY = 'Critical'),
    'total_downtime_hours', (SELECT ROUND(SUM(DOWNTIME_MINUTES) / 60.0, 1) FROM BD_INTELLIGENCE.RAW.INCIDENTS),
    'avg_resolution_time_hours', (
        SELECT ROUND(AVG(DATEDIFF(MINUTE, REPORTED_AT, RESOLVED_AT)) / 60.0, 1)
        FROM BD_INTELLIGENCE.RAW.INCIDENTS
        WHERE RESOLVED_AT IS NOT NULL
    ),
    'by_severity', (
        SELECT ARRAY_AGG(OBJECT_CONSTRUCT('severity', SEVERITY, 'count', N, 'total_downtime_hours', DOWNTIME_HOURS))
        FROM (SELECT SEVERITY, COUNT(*) AS N, ROUND(SUM(DOWNTIME_MINUTES) / 60.0, 1) AS DOWNTIME_HOURS
              FROM BD_INTELLIGENCE.RAW.INCIDENTS GROUP BY SEVERITY)
    ),
    'by_type', (
        SELECT ARRAY_AGG(OBJECT_CONSTRUCT('type', INCIDENT_TYPE, 'count', N))
        FROM (SELECT INCIDENT_TYPE, COUNT(*) AS N FROM BD_INTELLIGENCE.RAW.INCIDENTS GROUP BY INCIDENT_TYPE)
    ),
    'top_root_causes', (
        SELECT ARRAY_AGG(OBJECT_CONSTRUCT('cause', ROOT_CAUSE, 'count', N)) WITHIN GROUP (ORDER BY N DESC)
        FROM (SELECT ROOT_CAUSE, COUNT(*) AS N FROM BD_INTELLIGENCE.RAW.INCIDENTS
              GROUP BY ROOT_CAUSE ORDER BY N DESC LIMIT 5)
    )
)
$$;

-- ============================================================================
-- AGENT_GET_RUL_ESTIMATES: Remaining Useful Life estimates for components
-- ============================================================================
CREATE OR REPLACE FUNCTION AGENT_GET_RUL_ESTIMATES()
RETURNS ARRAY
AS
$$
SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
    'component_id', COMPONENT_ID,
    'robot_name', ROBOT_NAME,
    'robot_model', ROBOT_MODEL,
    'component_type', COMPONENT_TYPE,
    'component_name', COMPONENT_NAME,
    'days_in_service', DAYS_SINCE_INSTALL,
    'expected_lifespan_days', EXPECTED_LIFESPAN_DAYS,
    'estimated_remaining_days', ESTIMATED_REMAINING_DAYS,
    'runtime_hours', CURRENT_RUNTIME_HOURS,
    'lifecycle_utilization_pct', LIFECYCLE_PERCENT_USED,
    'urgency', URGENCY
)) FROM (
    SELECT
        ch.COMPONENT_ID,
        ch.ROBOT_NAME,
        ch.ROBOT_MODEL,
        ch.COMPONENT_TYPE,
        ch.COMPONENT_NAME,
        ch.DAYS_SINCE_INSTALL,
        ch.EXPECTED_LIFESPAN_DAYS,
        GREATEST(ch.EXPECTED_LIFESPAN_DAYS - ch.DAYS_SINCE_INSTALL, 0) AS ESTIMATED_REMAINING_DAYS,
        ch.CURRENT_RUNTIME_HOURS,
        ch.LIFECYCLE_PERCENT_USED,
        CASE
            WHEN ch.EXPECTED_LIFESPAN_DAYS - ch.DAYS_SINCE_INSTALL <= 0 THEN 'Overdue'
            WHEN ch.EXPECTED_LIFESPAN_DAYS - ch.DAYS_SINCE_INSTALL <= 30 THEN 'Urgent'
            WHEN ch.EXPECTED_LIFESPAN_DAYS - ch.DAYS_SINCE_INSTALL <= 90 THEN 'Soon'
            ELSE 'Normal'
        END AS URGENCY
    FROM BD_INTELLIGENCE.ANALYTICS.COMPONENT_HEALTH ch
    WHERE ch.EXPECTED_LIFESPAN_DAYS - ch.DAYS_SINCE_INSTALL <= 90
       OR ch.LIFECYCLE_PERCENT_USED >= 80
    ORDER BY ESTIMATED_REMAINING_DAYS ASC
    LIMIT 50
)
$$;

-- ============================================================================
-- CUSTOMER 360 AGENT FUNCTIONS
-- All read ANALYTICS.CUSTOMER_360, which joins the ML scores written by
-- notebooks/07_ml_models.ipynb (churn risk, health score, expansion propensity).
-- ============================================================================

-- ============================================================================
-- AGENT_GET_CUSTOMER_360: Full account brief for one customer (partial name ok)
-- ============================================================================
CREATE OR REPLACE FUNCTION AGENT_GET_CUSTOMER_360(CUSTOMER_NAME_FILTER VARCHAR)
RETURNS ARRAY
AS
$$
SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
    'customer_id', c.CUSTOMER_ID,
    'customer_name', c.CUSTOMER_NAME,
    'industry', c.INDUSTRY,
    'segment', c.SEGMENT,
    'region', c.REGION,
    'hq_city', c.HQ_CITY,
    'lifecycle_stage', c.LIFECYCLE_STAGE,
    'account_manager', c.ACCOUNT_MANAGER,
    'csm', c.CSM_NAME,
    'support_tier', c.SUPPORT_TIER,
    'customer_since', c.CUSTOMER_SINCE::VARCHAR,
    'contract_end_date', c.CONTRACT_END_DATE::VARCHAR,
    'days_to_renewal', c.DAYS_TO_RENEWAL,
    'contract_type', c.PRIMARY_CONTRACT_TYPE,
    'current_arr_usd', c.CURRENT_ARR_USD,
    'lifetime_contract_value_usd', c.LIFETIME_CONTRACT_VALUE_USD,
    'fleet', OBJECT_CONSTRUCT('sites', c.SITE_COUNT, 'robots', c.TOTAL_ROBOTS, 'atlas', c.ATLAS_COUNT,
                              'spot', c.SPOT_COUNT, 'stretch', c.STRETCH_COUNT),
    'ml_scores', OBJECT_CONSTRUCT('churn_risk_score', ROUND(c.CHURN_RISK_SCORE, 3), 'churn_risk_tier', c.CHURN_RISK_TIER,
                                  'health_score', c.HEALTH_SCORE, 'health_band', c.HEALTH_BAND,
                                  'expansion_propensity', ROUND(c.EXPANSION_PROPENSITY, 3), 'expansion_tier', c.EXPANSION_TIER,
                                  'top_risk_drivers', c.TOP_RISK_DRIVERS),
    'adoption', OBJECT_CONSTRUCT('utilization_pct_30d', c.UTILIZATION_PCT_30D, 'usage_trend_pct', c.USAGE_TREND_PCT,
                                 'autonomy_pct_30d', c.AUTONOMY_PCT_30D, 'missions_30d', c.MISSIONS_30D),
    'sentiment', OBJECT_CONSTRUCT('latest_nps', c.LATEST_NPS, 'latest_nps_category', c.LATEST_NPS_CATEGORY,
                                  'avg_nps_6m', c.AVG_NPS_6M, 'nps_trend', c.NPS_TREND,
                                  'negative_interaction_pct_90d', c.NEGATIVE_SENTIMENT_PCT_90D),
    'support', OBJECT_CONSTRUCT('tickets_90d', c.TICKETS_90D, 'open_tickets', c.OPEN_TICKETS,
                                'high_priority_tickets_90d', c.HIGH_PRIORITY_TICKETS_90D,
                                'sla_met_pct_90d', c.SLA_MET_PCT_90D, 'avg_ticket_csat_90d', c.AVG_TICKET_CSAT_90D),
    'reliability', OBJECT_CONSTRUCT('incidents_90d', c.INCIDENTS_90D, 'critical_incidents_90d', c.CRITICAL_INCIDENTS_90D,
                                    'downtime_minutes_90d', c.DOWNTIME_MINUTES_90D),
    'billing', OBJECT_CONSTRUCT('late_payment_pct_12m', c.LATE_PAYMENT_PCT_12M, 'overdue_amount_usd', c.OVERDUE_AMOUNT_USD),
    'pipeline', OBJECT_CONSTRUCT('open_pipeline_usd', c.OPEN_PIPELINE_USD, 'open_expansion_pipeline_usd', c.OPEN_EXPANSION_PIPELINE_USD,
                                 'expansion_won_12m_usd', c.EXPANSION_WON_12M_USD, 'renewal_stage', c.RENEWAL_STAGE,
                                 'renewal_probability_pct', c.RENEWAL_PROBABILITY_PCT),
    'last_interaction', OBJECT_CONSTRUCT('date', c.LAST_INTERACTION_DATE::VARCHAR, 'type', c.LAST_INTERACTION_TYPE,
                                         'days_since', c.DAYS_SINCE_LAST_INTERACTION),
    'contacts', (SELECT ARRAY_AGG(OBJECT_CONSTRUCT('name', ct.FULL_NAME, 'title', ct.TITLE, 'role', ct.CONTACT_ROLE,
                                                   'email', ct.EMAIL, 'is_primary', ct.IS_PRIMARY))
                 FROM BD_INTELLIGENCE.RAW.CONTACTS ct WHERE ct.CUSTOMER_ID = c.CUSTOMER_ID)
))
FROM BD_INTELLIGENCE.ANALYTICS.CUSTOMER_360 c
WHERE c.CUSTOMER_NAME ILIKE '%' || CUSTOMER_NAME_FILTER || '%'
$$;

-- ============================================================================
-- AGENT_GET_CHURN_RISK_LIST: Active customers ranked by ML churn risk
-- ============================================================================
CREATE OR REPLACE FUNCTION AGENT_GET_CHURN_RISK_LIST()
RETURNS ARRAY
AS
$$
SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
    'customer_name', CUSTOMER_NAME,
    'segment', SEGMENT,
    'industry', INDUSTRY,
    'churn_risk_score', ROUND(CHURN_RISK_SCORE, 3),
    'churn_risk_tier', CHURN_RISK_TIER,
    'health_score', HEALTH_SCORE,
    'health_band', HEALTH_BAND,
    'top_risk_drivers', TOP_RISK_DRIVERS,
    'current_arr_usd', CURRENT_ARR_USD,
    'days_to_renewal', DAYS_TO_RENEWAL,
    'contract_end_date', CONTRACT_END_DATE::VARCHAR,
    'latest_nps', LATEST_NPS,
    'utilization_pct_30d', UTILIZATION_PCT_30D,
    'open_tickets', OPEN_TICKETS,
    'account_manager', ACCOUNT_MANAGER,
    'csm', CSM_NAME,
    'recommended_action', CASE
        WHEN CHURN_RISK_TIER = 'High' AND DAYS_TO_RENEWAL <= 120 THEN 'Executive sponsor call within 5 days and remediation plan before renewal proposal'
        WHEN CHURN_RISK_TIER = 'High' THEN 'Open at-risk recovery plan; weekly status until health recovers above 70'
        WHEN CHURN_RISK_TIER = 'Medium' THEN 'CSM check-in and root-cause review of recent incidents and tickets'
        ELSE 'Routine monitoring' END
)) WITHIN GROUP (ORDER BY CHURN_RISK_SCORE DESC)
FROM (
    SELECT * FROM BD_INTELLIGENCE.ANALYTICS.CUSTOMER_360
    WHERE LIFECYCLE_STAGE <> 'Churned' AND CHURN_RISK_TIER IN ('High', 'Medium')
    ORDER BY CHURN_RISK_SCORE DESC
    LIMIT 25
)
$$;

-- ============================================================================
-- AGENT_GET_EXPANSION_OPPORTUNITIES: Customers ranked by expansion propensity
-- ============================================================================
CREATE OR REPLACE FUNCTION AGENT_GET_EXPANSION_OPPORTUNITIES()
RETURNS ARRAY
AS
$$
SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
    'customer_name', CUSTOMER_NAME,
    'segment', SEGMENT,
    'industry', INDUSTRY,
    'expansion_propensity', ROUND(EXPANSION_PROPENSITY, 3),
    'expansion_tier', EXPANSION_TIER,
    'health_score', HEALTH_SCORE,
    'current_arr_usd', CURRENT_ARR_USD,
    'total_robots', TOTAL_ROBOTS,
    'primary_product_line', PRIMARY_PRODUCT_LINE,
    'utilization_pct_30d', UTILIZATION_PCT_30D,
    'autonomy_pct_30d', AUTONOMY_PCT_30D,
    'latest_nps', LATEST_NPS,
    'open_expansion_pipeline_usd', OPEN_EXPANSION_PIPELINE_USD,
    'expansion_won_12m_usd', EXPANSION_WON_12M_USD,
    'account_manager', ACCOUNT_MANAGER,
    'suggested_play', CASE
        WHEN UTILIZATION_PCT_30D >= 85 THEN 'Fleet at capacity: propose additional robots at existing sites'
        WHEN AUTONOMY_PCT_30D >= 90 THEN 'Proven autonomy: replicate use case at a new site'
        WHEN PRIMARY_CONTRACT_TYPE <> 'RaaS Subscription' THEN 'Offer Robots-as-a-Service to scale faster'
        ELSE 'Upsell payloads (Spot Arm, CAM+IR thermal) and services' END
)) WITHIN GROUP (ORDER BY EXPANSION_PROPENSITY DESC)
FROM (
    SELECT * FROM BD_INTELLIGENCE.ANALYTICS.CUSTOMER_360
    WHERE LIFECYCLE_STAGE <> 'Churned' AND CHURN_RISK_TIER <> 'High'
    ORDER BY EXPANSION_PROPENSITY DESC
    LIMIT 25
)
$$;

-- ============================================================================
-- AGENT_GET_RENEWAL_CALENDAR: Contracts renewing in the next N days with risk
-- ============================================================================
CREATE OR REPLACE FUNCTION AGENT_GET_RENEWAL_CALENDAR(DAYS_AHEAD NUMBER)
RETURNS ARRAY
AS
$$
SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
    'customer_name', CUSTOMER_NAME,
    'contract_end_date', CONTRACT_END_DATE::VARCHAR,
    'days_to_renewal', DAYS_TO_RENEWAL,
    'current_arr_usd', CURRENT_ARR_USD,
    'contract_type', PRIMARY_CONTRACT_TYPE,
    'auto_renew', AUTO_RENEW,
    'renewal_stage', RENEWAL_STAGE,
    'renewal_probability_pct', RENEWAL_PROBABILITY_PCT,
    'churn_risk_tier', CHURN_RISK_TIER,
    'health_band', HEALTH_BAND,
    'top_risk_drivers', TOP_RISK_DRIVERS,
    'account_manager', ACCOUNT_MANAGER,
    'csm', CSM_NAME
)) WITHIN GROUP (ORDER BY CONTRACT_END_DATE)
FROM BD_INTELLIGENCE.ANALYTICS.CUSTOMER_360
WHERE LIFECYCLE_STAGE <> 'Churned'
  AND DAYS_TO_RENEWAL BETWEEN 0 AND DAYS_AHEAD
$$;

-- ============================================================================
-- AGENT_GET_ACCOUNT_HEALTH_SUMMARY: Portfolio-level customer health rollup
-- ============================================================================
CREATE OR REPLACE FUNCTION AGENT_GET_ACCOUNT_HEALTH_SUMMARY()
RETURNS OBJECT
AS
$$
SELECT OBJECT_CONSTRUCT(
    'total_customers', COUNT(*),
    'active_customers', COUNT_IF(LIFECYCLE_STAGE <> 'Churned'),
    'churned_customers', COUNT_IF(LIFECYCLE_STAGE = 'Churned'),
    'total_active_arr_usd', SUM(CURRENT_ARR_USD),
    'churned_arr_usd', SUM(CHURNED_ARR_USD),
    'arr_at_high_churn_risk_usd', SUM(IFF(CHURN_RISK_TIER = 'High' AND LIFECYCLE_STAGE <> 'Churned', CURRENT_ARR_USD, 0)),
    'high_churn_risk_active_customers', COUNT_IF(CHURN_RISK_TIER = 'High' AND LIFECYCLE_STAGE <> 'Churned'),
    'avg_health_score_active', ROUND(AVG(IFF(LIFECYCLE_STAGE <> 'Churned', HEALTH_SCORE, NULL)), 1),
    'health_bands_active', OBJECT_CONSTRUCT(
        'Healthy', COUNT_IF(HEALTH_BAND = 'Healthy' AND LIFECYCLE_STAGE <> 'Churned'),
        'Monitor', COUNT_IF(HEALTH_BAND = 'Monitor' AND LIFECYCLE_STAGE <> 'Churned'),
        'At Risk', COUNT_IF(HEALTH_BAND = 'At Risk' AND LIFECYCLE_STAGE <> 'Churned')),
    'high_expansion_customers', COUNT_IF(EXPANSION_TIER = 'High' AND LIFECYCLE_STAGE <> 'Churned'),
    'open_expansion_pipeline_usd', SUM(OPEN_EXPANSION_PIPELINE_USD),
    'renewals_next_90_days', COUNT_IF(DAYS_TO_RENEWAL BETWEEN 0 AND 90),
    'arr_renewing_next_90_days_usd', SUM(IFF(DAYS_TO_RENEWAL BETWEEN 0 AND 90, CURRENT_ARR_USD, 0)),
    'avg_nps_6m_active', ROUND(AVG(IFF(LIFECYCLE_STAGE <> 'Churned', AVG_NPS_6M, NULL)), 1),
    'avg_utilization_pct_active', ROUND(AVG(IFF(LIFECYCLE_STAGE <> 'Churned', UTILIZATION_PCT_30D, NULL)), 1),
    'total_overdue_usd', SUM(OVERDUE_AMOUNT_USD),
    'by_segment', (
        SELECT ARRAY_AGG(OBJECT_CONSTRUCT('segment', SEGMENT, 'customers', N, 'arr_usd', ARR,
                                          'avg_health_score', AVG_HEALTH, 'high_churn_risk', HIGH_RISK))
        FROM (SELECT SEGMENT, COUNT(*) AS N, SUM(CURRENT_ARR_USD) AS ARR, ROUND(AVG(HEALTH_SCORE), 1) AS AVG_HEALTH,
                     COUNT_IF(CHURN_RISK_TIER = 'High' AND LIFECYCLE_STAGE <> 'Churned') AS HIGH_RISK
              FROM BD_INTELLIGENCE.ANALYTICS.CUSTOMER_360
              WHERE LIFECYCLE_STAGE <> 'Churned'
              GROUP BY SEGMENT))
)
FROM BD_INTELLIGENCE.ANALYTICS.CUSTOMER_360
$$;
