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
        SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
            'type', MAINTENANCE_TYPE,
            'total_cost', ROUND(SUM(COST_USD), 2),
            'event_count', COUNT(*)
        )) FROM BD_INTELLIGENCE.RAW.MAINTENANCE_RECORDS GROUP BY MAINTENANCE_TYPE
    ),
    'cost_by_model', (
        SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
            'model', r.ROBOT_MODEL,
            'total_cost', ROUND(SUM(m.COST_USD), 2),
            'event_count', COUNT(*)
        )) FROM BD_INTELLIGENCE.RAW.MAINTENANCE_RECORDS m
        JOIN BD_INTELLIGENCE.RAW.ROBOTS r ON m.ROBOT_ID = r.ROBOT_ID
        GROUP BY r.ROBOT_MODEL
    ),
    'top_5_costliest_robots', (
        SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
            'robot_name', r.ROBOT_NAME,
            'robot_model', r.ROBOT_MODEL,
            'total_cost', ROUND(SUM(m.COST_USD), 2)
        )) FROM (
            SELECT ROBOT_ID, SUM(COST_USD) AS TOTAL_COST
            FROM BD_INTELLIGENCE.RAW.MAINTENANCE_RECORDS
            GROUP BY ROBOT_ID
            ORDER BY TOTAL_COST DESC
            LIMIT 5
        ) top
        JOIN BD_INTELLIGENCE.RAW.MAINTENANCE_RECORDS m ON top.ROBOT_ID = m.ROBOT_ID
        JOIN BD_INTELLIGENCE.RAW.ROBOTS r ON m.ROBOT_ID = r.ROBOT_ID
        GROUP BY r.ROBOT_NAME, r.ROBOT_MODEL
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
        SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
            'severity', SEVERITY,
            'count', COUNT(*),
            'total_downtime_hours', ROUND(SUM(DOWNTIME_MINUTES) / 60.0, 1)
        )) FROM BD_INTELLIGENCE.RAW.INCIDENTS GROUP BY SEVERITY
    ),
    'by_type', (
        SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
            'type', INCIDENT_TYPE,
            'count', COUNT(*)
        )) FROM BD_INTELLIGENCE.RAW.INCIDENTS GROUP BY INCIDENT_TYPE
    ),
    'top_root_causes', (
        SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
            'cause', ROOT_CAUSE,
            'count', COUNT(*)
        )) FROM BD_INTELLIGENCE.RAW.INCIDENTS GROUP BY ROOT_CAUSE ORDER BY COUNT(*) DESC LIMIT 5
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
