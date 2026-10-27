-- Added MAINTENANCE_MONTHLY_TREND view for time-series maintenance cost analysis
-- Co-authored with CoCo
/*=============================================================================
  Boston Dynamics Intelligence Agent
  Step 4: Analytical Views
  
  Execution Order: 4 of 9
  Description: Creates analytical views in the ANALYTICS schema that provide
               aggregated, business-ready data for fleet health, maintenance
               analysis, telemetry summaries, and operational dashboards.
=============================================================================*/

USE DATABASE BD_INTELLIGENCE;
USE SCHEMA ANALYTICS;
USE WAREHOUSE BOSTON_DYNAMICS_WH;

-- ============================================================================
-- Fleet Overview: Summary of all robots with their current status
-- ============================================================================
CREATE OR REPLACE VIEW FLEET_OVERVIEW
-- @cols-begin
(
    ROBOT_ID               COMMENT 'Robot identifier (BOT-00000 format). Joins to RAW.ROBOTS.',
    ROBOT_NAME             COMMENT 'Human-readable robot name, model plus sequence (for example Spot-019).',
    ROBOT_MODEL            COMMENT 'Robot platform: Atlas (humanoid), Spot (quadruped) or Stretch (warehouse case handling).',
    SERIAL_NUMBER          COMMENT 'Manufacturer serial number (BD-...).',
    ROBOT_STATUS           COMMENT 'Robot status: Active, Idle, Maintenance or Decommissioned.',
    FIRMWARE_VERSION       COMMENT 'Firmware version currently installed on the robot (major.minor.patch).',
    MANUFACTURE_DATE       COMMENT 'Date the robot was manufactured.',
    AGE_DAYS               COMMENT 'Days since the robot was manufactured.',
    DEPLOYMENT_ID          COMMENT 'Deployment site identifier (DEP-0000 format). Joins to RAW.DEPLOYMENTS.',
    SITE_NAME              COMMENT 'Name of the deployment site (facility and city).',
    SITE_TYPE              COMMENT 'Site environment category: Manufacturing Floor, Warehouse, Laboratory, Underground, Hazardous Area or Outdoor Industrial.',
    PRIMARY_USE_CASE       COMMENT 'Main job the robots perform at the site, for example Autonomous Inspection, Material Handling, Truck Unloading, Security Patrol or Inventory Management.',
    DEPLOYMENT_ENVIRONMENT COMMENT 'Operating environment of the site: Indoor, Outdoor, Mixed or Hazardous.',
    CUSTOMER_NAME          COMMENT 'Customer company name (for example Siemens Energy, Tesla Gigafactory).',
    CUSTOMER_INDUSTRY      COMMENT 'Industry of the customer that owns the site (same values as CUSTOMERS.INDUSTRY).',
    CUSTOMER_REGION        COMMENT 'Headquarters region of the customer that owns the site.',
    SUPPORT_TIER           COMMENT 'Purchased support entitlement: Platinum, Gold, Silver or Bronze. Higher tiers have tighter SLAs.',
    TOTAL_COMPONENTS       COMMENT 'Number of components installed on the robot.',
    HEALTHY_COMPONENTS     COMMENT 'Components with status Operational.',
    DEGRADED_COMPONENTS    COMMENT 'Components with status Degraded.',
    CRITICAL_COMPONENTS    COMMENT 'Components with status Needs Replacement or Failed.'
)
COMMENT = 'One row per robot with its deployment site, customer and a roll-up of component condition. Source for the BD_FLEET_OPERATIONS_SV semantic view.'
-- @cols-end
AS
SELECT
    r.ROBOT_ID,
    r.ROBOT_NAME,
    r.ROBOT_MODEL,
    r.SERIAL_NUMBER,
    r.STATUS AS ROBOT_STATUS,
    r.FIRMWARE_VERSION,
    r.MANUFACTURE_DATE,
    DATEDIFF(DAY, r.MANUFACTURE_DATE, CURRENT_DATE()) AS AGE_DAYS,
    d.DEPLOYMENT_ID,
    d.SITE_NAME,
    d.SITE_TYPE,
    d.PRIMARY_USE_CASE,
    d.ENVIRONMENT AS DEPLOYMENT_ENVIRONMENT,
    c.CUSTOMER_NAME,
    c.INDUSTRY AS CUSTOMER_INDUSTRY,
    c.REGION AS CUSTOMER_REGION,
    c.SUPPORT_TIER,
    COUNT(DISTINCT comp.COMPONENT_ID) AS TOTAL_COMPONENTS,
    SUM(CASE WHEN comp.STATUS = 'Operational' THEN 1 ELSE 0 END) AS HEALTHY_COMPONENTS,
    SUM(CASE WHEN comp.STATUS = 'Degraded' THEN 1 ELSE 0 END) AS DEGRADED_COMPONENTS,
    SUM(CASE WHEN comp.STATUS IN ('Needs Replacement', 'Failed') THEN 1 ELSE 0 END) AS CRITICAL_COMPONENTS
FROM BD_INTELLIGENCE.RAW.ROBOTS r
LEFT JOIN BD_INTELLIGENCE.RAW.DEPLOYMENTS d ON r.DEPLOYMENT_ID = d.DEPLOYMENT_ID
LEFT JOIN BD_INTELLIGENCE.RAW.CUSTOMERS c ON d.CUSTOMER_ID = c.CUSTOMER_ID
LEFT JOIN BD_INTELLIGENCE.RAW.COMPONENTS comp ON r.ROBOT_ID = comp.ROBOT_ID
GROUP BY
    r.ROBOT_ID, r.ROBOT_NAME, r.ROBOT_MODEL, r.SERIAL_NUMBER,
    r.STATUS, r.FIRMWARE_VERSION, r.MANUFACTURE_DATE,
    d.DEPLOYMENT_ID, d.SITE_NAME, d.SITE_TYPE, d.PRIMARY_USE_CASE, d.ENVIRONMENT,
    c.CUSTOMER_NAME, c.INDUSTRY, c.REGION, c.SUPPORT_TIER;

-- ============================================================================
-- Telemetry Summary: Aggregated telemetry stats per robot per day
-- ============================================================================
CREATE OR REPLACE VIEW TELEMETRY_DAILY_SUMMARY
-- @cols-begin
(
    ROBOT_ID          COMMENT 'Robot identifier (BOT-00000 format). Joins to RAW.ROBOTS.',
    ROBOT_NAME        COMMENT 'Human-readable robot name, model plus sequence (for example Spot-019).',
    ROBOT_MODEL       COMMENT 'Robot platform: Atlas (humanoid), Spot (quadruped) or Stretch (warehouse case handling).',
    TELEMETRY_DATE    COMMENT 'Calendar day of the readings.',
    READING_COUNT     COMMENT 'Number of telemetry readings on the day.',
    AVG_BATTERY_LEVEL COMMENT 'Average battery state of charge for the day, percent.',
    MIN_BATTERY_LEVEL COMMENT 'Lowest battery state of charge for the day, percent.',
    AVG_CPU_TEMP_C    COMMENT 'Average compute temperature for the day, degrees Celsius.',
    MAX_CPU_TEMP_C    COMMENT 'Highest compute temperature for the day, degrees Celsius.',
    AVG_MOTOR_TEMP_C  COMMENT 'Average motor temperature for the day, degrees Celsius.',
    MAX_MOTOR_TEMP_C  COMMENT 'Highest motor temperature for the day, degrees Celsius.',
    AVG_VIBRATION     COMMENT 'Average vibration for the day, mm/s.',
    MAX_VIBRATION     COMMENT 'Highest vibration for the day, mm/s.',
    AVG_JOINT_LOAD    COMMENT 'Average joint load for the day, percent of rated capacity.',
    MAX_JOINT_LOAD    COMMENT 'Highest joint load for the day, percent of rated capacity.',
    AVG_SPEED_M_S     COMMENT 'Average speed for the day, m/s.',
    MAX_SPEED_M_S     COMMENT 'Highest speed for the day, m/s.',
    ERROR_COUNT       COMMENT 'Number of readings on the day that carried an error code.',
    DISTINCT_MODES    COMMENT 'Number of distinct operating modes the robot used on the day.'
)
COMMENT = 'Telemetry aggregated to one row per robot per day: reading count, average/min/max of battery, temperatures, vibration, joint load and speed, plus error counts. Source for BD_TELEMETRY_ANALYTICS_SV.'
-- @cols-end
AS
SELECT
    t.ROBOT_ID,
    r.ROBOT_NAME,
    r.ROBOT_MODEL,
    DATE_TRUNC('DAY', t.TIMESTAMP)::DATE AS TELEMETRY_DATE,
    COUNT(*) AS READING_COUNT,
    ROUND(AVG(t.BATTERY_LEVEL), 1) AS AVG_BATTERY_LEVEL,
    ROUND(MIN(t.BATTERY_LEVEL), 1) AS MIN_BATTERY_LEVEL,
    ROUND(AVG(t.CPU_TEMPERATURE_C), 1) AS AVG_CPU_TEMP_C,
    ROUND(MAX(t.CPU_TEMPERATURE_C), 1) AS MAX_CPU_TEMP_C,
    ROUND(AVG(t.MOTOR_TEMPERATURE_C), 1) AS AVG_MOTOR_TEMP_C,
    ROUND(MAX(t.MOTOR_TEMPERATURE_C), 1) AS MAX_MOTOR_TEMP_C,
    ROUND(AVG(t.VIBRATION_MM_S), 2) AS AVG_VIBRATION,
    ROUND(MAX(t.VIBRATION_MM_S), 2) AS MAX_VIBRATION,
    ROUND(AVG(t.JOINT_LOAD_PERCENT), 1) AS AVG_JOINT_LOAD,
    ROUND(MAX(t.JOINT_LOAD_PERCENT), 1) AS MAX_JOINT_LOAD,
    ROUND(AVG(t.SPEED_M_S), 2) AS AVG_SPEED_M_S,
    ROUND(MAX(t.SPEED_M_S), 2) AS MAX_SPEED_M_S,
    SUM(CASE WHEN t.ERROR_CODE IS NOT NULL THEN 1 ELSE 0 END) AS ERROR_COUNT,
    COUNT(DISTINCT t.OPERATIONAL_MODE) AS DISTINCT_MODES
FROM BD_INTELLIGENCE.RAW.ROBOT_TELEMETRY t
JOIN BD_INTELLIGENCE.RAW.ROBOTS r ON t.ROBOT_ID = r.ROBOT_ID
GROUP BY t.ROBOT_ID, r.ROBOT_NAME, r.ROBOT_MODEL, DATE_TRUNC('DAY', t.TIMESTAMP)::DATE;

-- ============================================================================
-- Maintenance Analysis: Maintenance cost and frequency analytics
-- ============================================================================
CREATE OR REPLACE VIEW MAINTENANCE_ANALYSIS
-- @cols-begin
(
    ROBOT_ID                COMMENT 'Robot identifier (BOT-00000 format). Joins to RAW.ROBOTS.',
    ROBOT_NAME              COMMENT 'Human-readable robot name, model plus sequence (for example Spot-019).',
    ROBOT_MODEL             COMMENT 'Robot platform: Atlas (humanoid), Spot (quadruped) or Stretch (warehouse case handling).',
    SITE_NAME               COMMENT 'Name of the deployment site (facility and city).',
    CUSTOMER_NAME           COMMENT 'Customer company name (for example Siemens Energy, Tesla Gigafactory).',
    MAINTENANCE_TYPE        COMMENT 'Kind of maintenance: Preventive, Corrective, Predictive, Calibration or Firmware Update.',
    MAINTENANCE_COUNT       COMMENT 'Number of maintenance events for the robot and maintenance type.',
    TOTAL_COST_USD          COMMENT 'Total maintenance cost for the group in US dollars.',
    AVG_COST_USD            COMMENT 'Average cost per maintenance event in US dollars.',
    AVG_DURATION_MINUTES    COMMENT 'Average labour time per event in minutes.',
    TOTAL_DURATION_MINUTES  COMMENT 'Total labour time in minutes.',
    FIRST_MAINTENANCE_DATE  COMMENT 'Date of the earliest maintenance event in the group.',
    LAST_MAINTENANCE_DATE   COMMENT 'Date of the most recent maintenance event in the group.',
    PARTS_REPLACEMENT_COUNT COMMENT 'Number of events in the group where parts were replaced.'
)
COMMENT = 'Maintenance aggregated per robot and maintenance type over all history: event count, total/average cost and duration, first/last service date and parts replacements. Source for BD_MAINTENANCE_INTELLIGENCE_SV.'
-- @cols-end
AS
SELECT
    m.ROBOT_ID,
    r.ROBOT_NAME,
    r.ROBOT_MODEL,
    d.SITE_NAME,
    c.CUSTOMER_NAME,
    m.MAINTENANCE_TYPE,
    COUNT(*) AS MAINTENANCE_COUNT,
    ROUND(SUM(m.COST_USD), 2) AS TOTAL_COST_USD,
    ROUND(AVG(m.COST_USD), 2) AS AVG_COST_USD,
    ROUND(AVG(m.DURATION_MINUTES), 0) AS AVG_DURATION_MINUTES,
    SUM(m.DURATION_MINUTES) AS TOTAL_DURATION_MINUTES,
    MIN(m.PERFORMED_AT)::DATE AS FIRST_MAINTENANCE_DATE,
    MAX(m.PERFORMED_AT)::DATE AS LAST_MAINTENANCE_DATE,
    SUM(CASE WHEN m.PARTS_REPLACED IS NOT NULL THEN 1 ELSE 0 END) AS PARTS_REPLACEMENT_COUNT
FROM BD_INTELLIGENCE.RAW.MAINTENANCE_RECORDS m
JOIN BD_INTELLIGENCE.RAW.ROBOTS r ON m.ROBOT_ID = r.ROBOT_ID
LEFT JOIN BD_INTELLIGENCE.RAW.DEPLOYMENTS d ON r.DEPLOYMENT_ID = d.DEPLOYMENT_ID
LEFT JOIN BD_INTELLIGENCE.RAW.CUSTOMERS c ON d.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY m.ROBOT_ID, r.ROBOT_NAME, r.ROBOT_MODEL, d.SITE_NAME, c.CUSTOMER_NAME, m.MAINTENANCE_TYPE;

-- ============================================================================
-- Maintenance Monthly Trend: Event-level maintenance with month granularity
-- ============================================================================
CREATE OR REPLACE VIEW MAINTENANCE_MONTHLY_TREND
-- @cols-begin
(
    MAINTENANCE_MONTH       COMMENT 'First day of the month the maintenance was performed.',
    ROBOT_MODEL             COMMENT 'Robot platform: Atlas (humanoid), Spot (quadruped) or Stretch (warehouse case handling).',
    MAINTENANCE_TYPE        COMMENT 'Kind of maintenance: Preventive, Corrective, Predictive, Calibration or Firmware Update.',
    SITE_NAME               COMMENT 'Name of the deployment site (facility and city).',
    CUSTOMER_NAME           COMMENT 'Customer company name (for example Siemens Energy, Tesla Gigafactory).',
    TECHNICIAN              COMMENT 'Field technician who performed the work.',
    EVENT_COUNT             COMMENT 'Number of maintenance events in the group.',
    TOTAL_COST_USD          COMMENT 'Total maintenance cost for the group in US dollars.',
    AVG_COST_USD            COMMENT 'Average cost per maintenance event in US dollars.',
    TOTAL_DURATION_MINUTES  COMMENT 'Total labour time in minutes.',
    AVG_DURATION_MINUTES    COMMENT 'Average labour time per event in minutes.',
    PARTS_REPLACEMENT_COUNT COMMENT 'Number of events in the group where parts were replaced.'
)
COMMENT = 'Maintenance aggregated per month, robot model, maintenance type, site, customer and technician, for time-series analysis of cost, volume and duration. Source for BD_MAINTENANCE_TRENDS_SV.'
-- @cols-end
AS
SELECT
    DATE_TRUNC('MONTH', m.PERFORMED_AT)::DATE AS MAINTENANCE_MONTH,
    r.ROBOT_MODEL,
    m.MAINTENANCE_TYPE,
    d.SITE_NAME,
    c.CUSTOMER_NAME,
    m.PERFORMED_BY AS TECHNICIAN,
    COUNT(*) AS EVENT_COUNT,
    ROUND(SUM(m.COST_USD), 2) AS TOTAL_COST_USD,
    ROUND(AVG(m.COST_USD), 2) AS AVG_COST_USD,
    SUM(m.DURATION_MINUTES) AS TOTAL_DURATION_MINUTES,
    ROUND(AVG(m.DURATION_MINUTES), 0) AS AVG_DURATION_MINUTES,
    SUM(CASE WHEN m.PARTS_REPLACED IS NOT NULL THEN 1 ELSE 0 END) AS PARTS_REPLACEMENT_COUNT
FROM BD_INTELLIGENCE.RAW.MAINTENANCE_RECORDS m
JOIN BD_INTELLIGENCE.RAW.ROBOTS r ON m.ROBOT_ID = r.ROBOT_ID
LEFT JOIN BD_INTELLIGENCE.RAW.DEPLOYMENTS d ON r.DEPLOYMENT_ID = d.DEPLOYMENT_ID
LEFT JOIN BD_INTELLIGENCE.RAW.CUSTOMERS c ON d.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY DATE_TRUNC('MONTH', m.PERFORMED_AT)::DATE, r.ROBOT_MODEL, m.MAINTENANCE_TYPE,
         d.SITE_NAME, c.CUSTOMER_NAME, m.PERFORMED_BY;

-- ============================================================================
-- Incident Dashboard: Incident frequency and severity analysis
-- ============================================================================
CREATE OR REPLACE VIEW INCIDENT_DASHBOARD
-- @cols-begin
(
    ROBOT_ID               COMMENT 'Robot identifier (BOT-00000 format). Joins to RAW.ROBOTS.',
    ROBOT_NAME             COMMENT 'Human-readable robot name, model plus sequence (for example Spot-019).',
    ROBOT_MODEL            COMMENT 'Robot platform: Atlas (humanoid), Spot (quadruped) or Stretch (warehouse case handling).',
    SITE_NAME              COMMENT 'Name of the deployment site (facility and city).',
    CUSTOMER_NAME          COMMENT 'Customer company name (for example Siemens Energy, Tesla Gigafactory).',
    CUSTOMER_INDUSTRY      COMMENT 'Industry of the customer that owns the site (same values as CUSTOMERS.INDUSTRY).',
    INCIDENT_TYPE          COMMENT 'Incident category: Hardware Failure, Battery Critical, Sensor Malfunction, Emergency Stop, Environmental Hazard, Communication Loss, Software Error or Navigation Error.',
    SEVERITY               COMMENT 'Incident severity: Critical, High, Medium or Low.',
    INCIDENT_COUNT         COMMENT 'Number of incidents in the group.',
    TOTAL_DOWNTIME_MINUTES COMMENT 'Total incident downtime in minutes.',
    AVG_DOWNTIME_MINUTES   COMMENT 'Average downtime per incident in minutes.',
    RESOLVED_COUNT         COMMENT 'Incidents that have been resolved.',
    UNRESOLVED_COUNT       COMMENT 'Incidents still open (no RESOLVED_AT).',
    FIRST_INCIDENT_DATE    COMMENT 'Date of the earliest incident in the group.',
    LAST_INCIDENT_DATE     COMMENT 'Date of the most recent incident in the group.'
)
COMMENT = 'Incidents aggregated per robot, incident type and severity: count, downtime, resolved vs unresolved and first/last occurrence. Source for BD_INCIDENT_ANALYSIS_SV.'
-- @cols-end
AS
SELECT
    i.ROBOT_ID,
    r.ROBOT_NAME,
    r.ROBOT_MODEL,
    d.SITE_NAME,
    c.CUSTOMER_NAME,
    c.INDUSTRY AS CUSTOMER_INDUSTRY,
    i.INCIDENT_TYPE,
    i.SEVERITY,
    COUNT(*) AS INCIDENT_COUNT,
    SUM(i.DOWNTIME_MINUTES) AS TOTAL_DOWNTIME_MINUTES,
    ROUND(AVG(i.DOWNTIME_MINUTES), 0) AS AVG_DOWNTIME_MINUTES,
    SUM(CASE WHEN i.RESOLVED_AT IS NOT NULL THEN 1 ELSE 0 END) AS RESOLVED_COUNT,
    SUM(CASE WHEN i.RESOLVED_AT IS NULL THEN 1 ELSE 0 END) AS UNRESOLVED_COUNT,
    MIN(i.REPORTED_AT)::DATE AS FIRST_INCIDENT_DATE,
    MAX(i.REPORTED_AT)::DATE AS LAST_INCIDENT_DATE
FROM BD_INTELLIGENCE.RAW.INCIDENTS i
JOIN BD_INTELLIGENCE.RAW.ROBOTS r ON i.ROBOT_ID = r.ROBOT_ID
LEFT JOIN BD_INTELLIGENCE.RAW.DEPLOYMENTS d ON i.DEPLOYMENT_ID = d.DEPLOYMENT_ID
LEFT JOIN BD_INTELLIGENCE.RAW.CUSTOMERS c ON d.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY i.ROBOT_ID, r.ROBOT_NAME, r.ROBOT_MODEL, d.SITE_NAME, c.CUSTOMER_NAME, c.INDUSTRY, i.INCIDENT_TYPE, i.SEVERITY;

-- ============================================================================
-- Component Health: Component status and lifecycle tracking
-- ============================================================================
CREATE OR REPLACE VIEW COMPONENT_HEALTH
-- @cols-begin
(
    COMPONENT_ID           COMMENT 'Component identifier (COMP-00000 format). Joins to RAW.COMPONENTS.',
    ROBOT_ID               COMMENT 'Robot identifier (BOT-00000 format). Joins to RAW.ROBOTS.',
    ROBOT_NAME             COMMENT 'Human-readable robot name, model plus sequence (for example Spot-019).',
    ROBOT_MODEL            COMMENT 'Robot platform: Atlas (humanoid), Spot (quadruped) or Stretch (warehouse case handling).',
    COMPONENT_TYPE         COMMENT 'Component category: Motor, Battery, Sensor, LiDAR, Camera, Joint Actuator, Hydraulic Pump, Gripper, Controller Board or Communication Module.',
    COMPONENT_NAME         COMMENT 'Specific component name (for example Knee Motor, Precision Gripper).',
    COMPONENT_STATUS       COMMENT 'Condition at last inspection: Operational, Degraded, Needs Replacement or Failed.',
    INSTALL_DATE           COMMENT 'Date the component was installed on the robot.',
    DAYS_SINCE_INSTALL     COMMENT 'Days since the component was installed (CURRENT_DATE minus INSTALL_DATE).',
    EXPECTED_LIFESPAN_DAYS COMMENT 'Rated design lifespan of the component in days (365-3,991).',
    LIFECYCLE_PERCENT_USED COMMENT 'Age as a percentage of rated lifespan (DAYS_SINCE_INSTALL / EXPECTED_LIFESPAN_DAYS x 100). Above 100 means the component is past its rated life.',
    CURRENT_RUNTIME_HOURS  COMMENT 'Cumulative operating hours on the component since installation.',
    LAST_INSPECTION_DATE   COMMENT 'Date of the most recent technician inspection of the component.',
    DAYS_SINCE_INSPECTION  COMMENT 'Days since the last inspection.',
    INSPECTION_RUL_DAYS    COMMENT 'Remaining useful life in days estimated at the last inspection from observed wear (0 = worn out). Target of the BD_REMAINING_USEFUL_LIFE model. Unlike EXPECTED_LIFESPAN_DAYS minus age, it reflects actual condition.',
    SITE_NAME              COMMENT 'Name of the deployment site (facility and city).',
    CUSTOMER_NAME          COMMENT 'Customer company name (for example Siemens Energy, Tesla Gigafactory).',
    RISK_LEVEL             COMMENT 'Rule-based replacement risk: Critical (Failed), High (Needs Replacement or more than 90% of rated life used), Medium (Degraded or more than 75% used), otherwise Low.'
)
COMMENT = 'One row per component with age, lifecycle consumption, inspection-based remaining useful life and a rule-based risk level. Used by the RUL agent tool and the Robot RUL Streamlit dashboard.'
-- @cols-end
AS
SELECT
    comp.COMPONENT_ID,
    comp.ROBOT_ID,
    r.ROBOT_NAME,
    r.ROBOT_MODEL,
    comp.COMPONENT_TYPE,
    comp.COMPONENT_NAME,
    comp.STATUS AS COMPONENT_STATUS,
    comp.INSTALL_DATE,
    DATEDIFF(DAY, comp.INSTALL_DATE, CURRENT_DATE()) AS DAYS_SINCE_INSTALL,
    comp.EXPECTED_LIFESPAN_DAYS,
    ROUND(DATEDIFF(DAY, comp.INSTALL_DATE, CURRENT_DATE()) * 100.0 / NULLIF(comp.EXPECTED_LIFESPAN_DAYS, 0), 1) AS LIFECYCLE_PERCENT_USED,
    comp.CURRENT_RUNTIME_HOURS,
    comp.LAST_INSPECTION_DATE,
    DATEDIFF(DAY, comp.LAST_INSPECTION_DATE, CURRENT_DATE()) AS DAYS_SINCE_INSPECTION,
    comp.INSPECTION_RUL_DAYS,
    d.SITE_NAME,
    c.CUSTOMER_NAME,
    CASE
        WHEN comp.STATUS = 'Failed' THEN 'Critical'
        WHEN comp.STATUS = 'Needs Replacement' THEN 'High'
        WHEN DATEDIFF(DAY, comp.INSTALL_DATE, CURRENT_DATE()) > comp.EXPECTED_LIFESPAN_DAYS * 0.9 THEN 'High'
        WHEN comp.STATUS = 'Degraded' THEN 'Medium'
        WHEN DATEDIFF(DAY, comp.INSTALL_DATE, CURRENT_DATE()) > comp.EXPECTED_LIFESPAN_DAYS * 0.75 THEN 'Medium'
        ELSE 'Low'
    END AS RISK_LEVEL
FROM BD_INTELLIGENCE.RAW.COMPONENTS comp
JOIN BD_INTELLIGENCE.RAW.ROBOTS r ON comp.ROBOT_ID = r.ROBOT_ID
LEFT JOIN BD_INTELLIGENCE.RAW.DEPLOYMENTS d ON r.DEPLOYMENT_ID = d.DEPLOYMENT_ID
LEFT JOIN BD_INTELLIGENCE.RAW.CUSTOMERS c ON d.CUSTOMER_ID = c.CUSTOMER_ID;

-- ============================================================================
-- Customer Fleet Summary: Per-customer fleet health overview
-- ============================================================================
CREATE OR REPLACE VIEW CUSTOMER_FLEET_SUMMARY
-- @cols-begin
(
    CUSTOMER_ID            COMMENT 'Customer account identifier (CUST-0000 format). Joins to RAW.CUSTOMERS.',
    CUSTOMER_NAME          COMMENT 'Customer company name (for example Siemens Energy, Tesla Gigafactory).',
    INDUSTRY               COMMENT 'Customer industry: Automotive Manufacturing, Logistics & Warehousing, Energy & Utilities, Aerospace & Defense, Industrial Manufacturing or Mining & Resources.',
    REGION                 COMMENT 'Customer headquarters region: North America, Europe, Asia Pacific, South America or Middle East & Africa.',
    COUNTRY                COMMENT 'Country of the customer headquarters.',
    SUPPORT_TIER           COMMENT 'Purchased support entitlement: Platinum, Gold, Silver or Bronze. Higher tiers have tighter SLAs.',
    ACCOUNT_MANAGER        COMMENT 'Boston Dynamics account executive who owns the commercial relationship.',
    ACTIVE_DEPLOYMENTS     COMMENT 'Number of deployment sites for the customer (all statuses).',
    TOTAL_ROBOTS           COMMENT 'Number of robots deployed across the customer''s sites.',
    ACTIVE_ROBOTS          COMMENT 'Number of robots with status Active.',
    ROBOTS_IN_MAINTENANCE  COMMENT 'Number of robots with status Maintenance.',
    ATLAS_COUNT            COMMENT 'Number of Atlas robots.',
    SPOT_COUNT             COMMENT 'Number of Spot robots.',
    STRETCH_COUNT          COMMENT 'Number of Stretch robots.',
    TOTAL_MAINTENANCE_COST COMMENT 'Total maintenance cost over all history in US dollars.',
    TOTAL_INCIDENTS        COMMENT 'Total number of incidents over all history.',
    TOTAL_DOWNTIME_MINUTES COMMENT 'Total incident downtime in minutes.'
)
COMMENT = 'One row per customer summarising deployments, robot counts by status and model, total maintenance cost, incidents and downtime over all history.'
-- @cols-end
AS
SELECT
    c.CUSTOMER_ID,
    c.CUSTOMER_NAME,
    c.INDUSTRY,
    c.REGION,
    c.COUNTRY,
    c.SUPPORT_TIER,
    c.ACCOUNT_MANAGER,
    COUNT(DISTINCT d.DEPLOYMENT_ID) AS ACTIVE_DEPLOYMENTS,
    COUNT(DISTINCT r.ROBOT_ID) AS TOTAL_ROBOTS,
    SUM(CASE WHEN r.STATUS = 'Active' THEN 1 ELSE 0 END) AS ACTIVE_ROBOTS,
    SUM(CASE WHEN r.STATUS = 'Maintenance' THEN 1 ELSE 0 END) AS ROBOTS_IN_MAINTENANCE,
    SUM(CASE WHEN r.ROBOT_MODEL = 'Atlas' THEN 1 ELSE 0 END) AS ATLAS_COUNT,
    SUM(CASE WHEN r.ROBOT_MODEL = 'Spot' THEN 1 ELSE 0 END) AS SPOT_COUNT,
    SUM(CASE WHEN r.ROBOT_MODEL = 'Stretch' THEN 1 ELSE 0 END) AS STRETCH_COUNT,
    ROUND(SUM(maint.TOTAL_MAINT_COST), 2) AS TOTAL_MAINTENANCE_COST,
    COALESCE(SUM(inc.INCIDENT_COUNT), 0) AS TOTAL_INCIDENTS,
    COALESCE(SUM(inc.TOTAL_DOWNTIME), 0) AS TOTAL_DOWNTIME_MINUTES
FROM BD_INTELLIGENCE.RAW.CUSTOMERS c
LEFT JOIN BD_INTELLIGENCE.RAW.DEPLOYMENTS d ON c.CUSTOMER_ID = d.CUSTOMER_ID
LEFT JOIN BD_INTELLIGENCE.RAW.ROBOTS r ON d.DEPLOYMENT_ID = r.DEPLOYMENT_ID
LEFT JOIN (
    SELECT ROBOT_ID, SUM(COST_USD) AS TOTAL_MAINT_COST
    FROM BD_INTELLIGENCE.RAW.MAINTENANCE_RECORDS
    GROUP BY ROBOT_ID
) maint ON r.ROBOT_ID = maint.ROBOT_ID
LEFT JOIN (
    SELECT ROBOT_ID, COUNT(*) AS INCIDENT_COUNT, SUM(DOWNTIME_MINUTES) AS TOTAL_DOWNTIME
    FROM BD_INTELLIGENCE.RAW.INCIDENTS
    GROUP BY ROBOT_ID
) inc ON r.ROBOT_ID = inc.ROBOT_ID
GROUP BY c.CUSTOMER_ID, c.CUSTOMER_NAME, c.INDUSTRY, c.REGION, c.COUNTRY, c.SUPPORT_TIER, c.ACCOUNT_MANAGER;

-- ============================================================================
-- Robot Model Performance: Comparative performance across robot models
-- ============================================================================
CREATE OR REPLACE VIEW ROBOT_MODEL_PERFORMANCE
-- @cols-begin
(
    ROBOT_MODEL                    COMMENT 'Robot platform: Atlas (humanoid), Spot (quadruped) or Stretch (warehouse case handling).',
    TOTAL_UNITS                    COMMENT 'Number of robots of the model.',
    ACTIVE_UNITS                   COMMENT 'Number of robots of the model with status Active.',
    AVG_AGE_DAYS                   COMMENT 'Average robot age in days since manufacture.',
    FLEET_AVG_BATTERY              COMMENT 'Average battery level across all readings for the model, percent.',
    FLEET_AVG_MOTOR_TEMP           COMMENT 'Average motor temperature across all readings for the model, degrees Celsius.',
    FLEET_AVG_VIBRATION            COMMENT 'Average vibration across all readings for the model, mm/s.',
    TOTAL_INCIDENTS                COMMENT 'Total number of incidents over all history.',
    INCIDENTS_PER_ROBOT            COMMENT 'Total incidents divided by number of robots of the model.',
    TOTAL_MAINTENANCE_COST         COMMENT 'Total maintenance cost over all history in US dollars.',
    AVG_MAINTENANCE_COST_PER_ROBOT COMMENT 'Total maintenance cost divided by number of robots of the model, US dollars.'
)
COMMENT = 'One row per robot model (Atlas, Spot, Stretch) comparing fleet size, age, average telemetry, incident rate and maintenance cost per robot.'
-- @cols-end
AS
SELECT
    r.ROBOT_MODEL,
    COUNT(DISTINCT r.ROBOT_ID) AS TOTAL_UNITS,
    SUM(CASE WHEN r.STATUS = 'Active' THEN 1 ELSE 0 END) AS ACTIVE_UNITS,
    ROUND(AVG(DATEDIFF(DAY, r.MANUFACTURE_DATE, CURRENT_DATE())), 0) AS AVG_AGE_DAYS,
    ROUND(AVG(tel.AVG_BATTERY), 1) AS FLEET_AVG_BATTERY,
    ROUND(AVG(tel.AVG_MOTOR_TEMP), 1) AS FLEET_AVG_MOTOR_TEMP,
    ROUND(AVG(tel.AVG_VIBRATION), 2) AS FLEET_AVG_VIBRATION,
    COALESCE(SUM(inc.INCIDENT_COUNT), 0) AS TOTAL_INCIDENTS,
    ROUND(COALESCE(SUM(inc.INCIDENT_COUNT), 0) * 1.0 / NULLIF(COUNT(DISTINCT r.ROBOT_ID), 0), 2) AS INCIDENTS_PER_ROBOT,
    ROUND(COALESCE(SUM(maint.TOTAL_COST), 0), 2) AS TOTAL_MAINTENANCE_COST,
    ROUND(COALESCE(SUM(maint.TOTAL_COST), 0) / NULLIF(COUNT(DISTINCT r.ROBOT_ID), 0), 2) AS AVG_MAINTENANCE_COST_PER_ROBOT
FROM BD_INTELLIGENCE.RAW.ROBOTS r
LEFT JOIN (
    SELECT ROBOT_ID,
        AVG(BATTERY_LEVEL) AS AVG_BATTERY,
        AVG(MOTOR_TEMPERATURE_C) AS AVG_MOTOR_TEMP,
        AVG(VIBRATION_MM_S) AS AVG_VIBRATION
    FROM BD_INTELLIGENCE.RAW.ROBOT_TELEMETRY
    GROUP BY ROBOT_ID
) tel ON r.ROBOT_ID = tel.ROBOT_ID
LEFT JOIN (
    SELECT ROBOT_ID, COUNT(*) AS INCIDENT_COUNT
    FROM BD_INTELLIGENCE.RAW.INCIDENTS
    GROUP BY ROBOT_ID
) inc ON r.ROBOT_ID = inc.ROBOT_ID
LEFT JOIN (
    SELECT ROBOT_ID, SUM(COST_USD) AS TOTAL_COST
    FROM BD_INTELLIGENCE.RAW.MAINTENANCE_RECORDS
    GROUP BY ROBOT_ID
) maint ON r.ROBOT_ID = maint.ROBOT_ID
GROUP BY r.ROBOT_MODEL;

-- ============================================================================
-- Deployment Performance: Performance metrics per deployment site
-- ============================================================================
CREATE OR REPLACE VIEW DEPLOYMENT_PERFORMANCE
-- @cols-begin
(
    DEPLOYMENT_ID          COMMENT 'Deployment site identifier (DEP-0000 format). Joins to RAW.DEPLOYMENTS.',
    SITE_NAME              COMMENT 'Name of the deployment site (facility and city).',
    SITE_TYPE              COMMENT 'Site environment category: Manufacturing Floor, Warehouse, Laboratory, Underground, Hazardous Area or Outdoor Industrial.',
    PRIMARY_USE_CASE       COMMENT 'Main job the robots perform at the site, for example Autonomous Inspection, Material Handling, Truck Unloading, Security Patrol or Inventory Management.',
    ENVIRONMENT            COMMENT 'Operating environment: Indoor, Outdoor, Mixed or Hazardous.',
    DEPLOYMENT_DATE        COMMENT 'Date robots were first deployed at the site.',
    DAYS_SINCE_DEPLOYMENT  COMMENT 'Days since the site went live.',
    DEPLOYMENT_STATUS      COMMENT 'Site status: Active, Maintenance or Decommissioned.',
    CUSTOMER_NAME          COMMENT 'Customer company name (for example Siemens Energy, Tesla Gigafactory).',
    INDUSTRY               COMMENT 'Customer industry: Automotive Manufacturing, Logistics & Warehousing, Energy & Utilities, Aerospace & Defense, Industrial Manufacturing or Mining & Resources.',
    ROBOT_COUNT            COMMENT 'Number of robots assigned to the site.',
    ACTIVE_ROBOTS          COMMENT 'Robots at the site with status Active.',
    TOTAL_INCIDENTS        COMMENT 'Total number of incidents over all history.',
    TOTAL_DOWNTIME_MINUTES COMMENT 'Total incident downtime in minutes.',
    TOTAL_MAINTENANCE_COST COMMENT 'Total maintenance cost over all history in US dollars.'
)
COMMENT = 'One row per deployment site with customer, robot counts, total incidents, downtime and maintenance cost.'
-- @cols-end
AS
SELECT
    d.DEPLOYMENT_ID,
    d.SITE_NAME,
    d.SITE_TYPE,
    d.PRIMARY_USE_CASE,
    d.ENVIRONMENT,
    d.DEPLOYMENT_DATE,
    DATEDIFF(DAY, d.DEPLOYMENT_DATE, CURRENT_DATE()) AS DAYS_SINCE_DEPLOYMENT,
    d.STATUS AS DEPLOYMENT_STATUS,
    c.CUSTOMER_NAME,
    c.INDUSTRY,
    COUNT(DISTINCT r.ROBOT_ID) AS ROBOT_COUNT,
    SUM(CASE WHEN r.STATUS = 'Active' THEN 1 ELSE 0 END) AS ACTIVE_ROBOTS,
    COALESCE(SUM(inc.INCIDENT_COUNT), 0) AS TOTAL_INCIDENTS,
    COALESCE(SUM(inc.TOTAL_DOWNTIME), 0) AS TOTAL_DOWNTIME_MINUTES,
    ROUND(COALESCE(SUM(maint.TOTAL_COST), 0), 2) AS TOTAL_MAINTENANCE_COST
FROM BD_INTELLIGENCE.RAW.DEPLOYMENTS d
LEFT JOIN BD_INTELLIGENCE.RAW.CUSTOMERS c ON d.CUSTOMER_ID = c.CUSTOMER_ID
LEFT JOIN BD_INTELLIGENCE.RAW.ROBOTS r ON d.DEPLOYMENT_ID = r.DEPLOYMENT_ID
LEFT JOIN (
    SELECT ROBOT_ID, COUNT(*) AS INCIDENT_COUNT, SUM(DOWNTIME_MINUTES) AS TOTAL_DOWNTIME
    FROM BD_INTELLIGENCE.RAW.INCIDENTS
    GROUP BY ROBOT_ID
) inc ON r.ROBOT_ID = inc.ROBOT_ID
LEFT JOIN (
    SELECT ROBOT_ID, SUM(COST_USD) AS TOTAL_COST
    FROM BD_INTELLIGENCE.RAW.MAINTENANCE_RECORDS
    GROUP BY ROBOT_ID
) maint ON r.ROBOT_ID = maint.ROBOT_ID
GROUP BY d.DEPLOYMENT_ID, d.SITE_NAME, d.SITE_TYPE, d.PRIMARY_USE_CASE, d.ENVIRONMENT,
         d.DEPLOYMENT_DATE, d.STATUS, c.CUSTOMER_NAME, c.INDUSTRY;

-- ============================================================================
-- CUSTOMER 360 VIEWS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- ML scores table (populated by notebooks/07_ml_models.ipynb) and
-- Customer 360: one row per customer combining commercial, adoption, support,
-- sentiment, reliability and pipeline signals. Windows are measured relative
-- to AS_OF_DATE (contract end for churned customers, today otherwise) so that
-- churned and active accounts are comparable for ML training.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS CUSTOMER_ML_SCORES (
    CUSTOMER_ID             VARCHAR(50) NOT NULL,
    CHURN_RISK_SCORE        FLOAT,          -- 0-1 probability of churn / non-renewal
    CHURN_RISK_TIER         VARCHAR(20),    -- High / Medium / Low
    HEALTH_SCORE            FLOAT,          -- 0-100
    HEALTH_BAND             VARCHAR(20),    -- Healthy / Monitor / At Risk
    EXPANSION_PROPENSITY    FLOAT,          -- 0-1 probability of expansion
    EXPANSION_TIER          VARCHAR(20),    -- High / Medium / Low
    TOP_RISK_DRIVERS        VARCHAR(1000),
    MODEL_VERSION           VARCHAR(50),
    SCORED_AT               TIMESTAMP_NTZ
);

CREATE OR REPLACE VIEW CUSTOMER_360
-- @cols-begin
(
    CUSTOMER_ID                 COMMENT 'Customer account identifier (CUST-0000 format). Joins to RAW.CUSTOMERS.',
    CUSTOMER_NAME               COMMENT 'Customer company name (for example Siemens Energy, Tesla Gigafactory).',
    INDUSTRY                    COMMENT 'Customer industry: Automotive Manufacturing, Logistics & Warehousing, Energy & Utilities, Aerospace & Defense, Industrial Manufacturing or Mining & Resources.',
    SEGMENT                     COMMENT 'Go-to-market segment based on annual revenue: Strategic (largest), Enterprise or Commercial.',
    COMPANY_SIZE                COMMENT 'Legacy size band: Enterprise, Large or Mid-Market. Prefer SEGMENT for Customer 360 analysis.',
    REGION                      COMMENT 'Customer headquarters region: North America, Europe, Asia Pacific, South America or Middle East & Africa.',
    COUNTRY                     COMMENT 'Country of the customer headquarters.',
    HQ_CITY                     COMMENT 'City of the customer headquarters.',
    ANNUAL_REVENUE_USD          COMMENT 'Customer company annual revenue in US dollars (the customer''s own revenue, not spend with Boston Dynamics). Log-uniform between about $2B and $386B.',
    EMPLOYEE_COUNT              COMMENT 'Approximate number of employees at the customer company.',
    SUPPORT_TIER                COMMENT 'Purchased support entitlement: Platinum, Gold, Silver or Bronze. Higher tiers have tighter SLAs.',
    ACCOUNT_MANAGER             COMMENT 'Boston Dynamics account executive who owns the commercial relationship.',
    CSM_NAME                    COMMENT 'Customer Success Manager assigned to the account.',
    LIFECYCLE_STAGE             COMMENT 'Account lifecycle stage: Onboarding, Adopting, Mature, Renewal Due or Churned. Churned accounts have no active contract.',
    CUSTOMER_SINCE              COMMENT 'Date the customer signed its first contract with Boston Dynamics.',
    TENURE_DAYS                 COMMENT 'Days from CUSTOMER_SINCE to the as-of date.',
    CONTRACT_START_DATE         COMMENT 'Start date of the customer''s current (or final, if churned) contract term.',
    CONTRACT_END_DATE           COMMENT 'End date of the current contract term, i.e. the next renewal date. For churned customers, the churn date.',
    DAYS_TO_RENEWAL             COMMENT 'Days from today until CONTRACT_END_DATE (negative if past due). NULL for churned customers.',
    AS_OF_DATE                  COMMENT 'Reference date for all rolling windows: today for current customers, the churn date (CONTRACT_END_DATE) for churned customers.',
    SITE_COUNT                  COMMENT 'Number of deployment sites for the customer.',
    TOTAL_ROBOTS                COMMENT 'Number of robots deployed across the customer''s sites.',
    ACTIVE_ROBOTS               COMMENT 'Number of robots with status Active.',
    ATLAS_COUNT                 COMMENT 'Number of Atlas robots.',
    SPOT_COUNT                  COMMENT 'Number of Spot robots.',
    STRETCH_COUNT               COMMENT 'Number of Stretch robots.',
    CURRENT_ARR_USD             COMMENT 'Annual recurring revenue from the customer''s Active contracts, US dollars. 0 for churned customers.',
    CHURNED_ARR_USD             COMMENT 'ARR of the customer''s contracts with status Churned, US dollars.',
    LIFETIME_CONTRACT_VALUE_USD COMMENT 'Sum of total contract value across all of the customer''s contracts, US dollars.',
    CONTRACT_COUNT              COMMENT 'Number of contracts (all terms and expansions) for the customer.',
    RENEWAL_COUNT               COMMENT 'Number of past contract terms that were renewed.',
    PRIMARY_CONTRACT_TYPE       COMMENT 'Main commercial model of the account (RaaS Subscription, Purchase + Support or Lease), excluding Expansion add-ons.',
    PRIMARY_PRODUCT_LINE        COMMENT 'Main robot product line under contract (Atlas, Spot or Stretch).',
    AUTO_RENEW                  COMMENT 'TRUE if any Active contract auto-renews.',
    INCIDENTS_90D               COMMENT 'Robot incidents at the customer''s sites in the 90 days before the as-of date.',
    CRITICAL_INCIDENTS_90D      COMMENT 'Critical-severity incidents in the 90 days before the as-of / snapshot date.',
    DOWNTIME_MINUTES_90D        COMMENT 'Incident downtime in minutes in the 90 days before the as-of date.',
    INCIDENTS_PER_ROBOT_90D     COMMENT 'INCIDENTS_90D divided by TOTAL_ROBOTS.',
    TICKETS_90D                 COMMENT 'Support tickets opened in the 90 days before the as-of date.',
    HIGH_PRIORITY_TICKETS_90D   COMMENT 'Critical or High priority tickets opened in the 90 days before the as-of / snapshot date.',
    OPEN_TICKETS                COMMENT 'Tickets opened in the last 90 days that are still Open.',
    TICKETS_PER_ROBOT_90D       COMMENT 'Tickets opened in the last 90 days divided by TOTAL_ROBOTS.',
    SLA_MET_PCT_90D             COMMENT 'Percentage of tickets opened in the last 90 days that met SLA (0-100).',
    AVG_TICKET_CSAT_90D         COMMENT 'Average ticket CSAT (1-5) for tickets opened in the last 90 days.',
    AVG_RESOLUTION_HOURS_90D    COMMENT 'Average hours to resolve tickets opened in the last 90 days.',
    LATEST_NPS                  COMMENT 'Most recent NPS score (0-10) from any contact at the customer.',
    LATEST_NPS_CATEGORY         COMMENT 'Category of the most recent NPS response: Promoter, Passive or Detractor.',
    AVG_NPS_6M                  COMMENT 'Average NPS score (0-10, not the -100 to +100 index) over the 180 days before the as-of / snapshot date.',
    AVG_NPS_PRIOR_6M            COMMENT 'Average NPS score (0-10) for responses older than 180 days before the as-of date.',
    NPS_TREND                   COMMENT 'Change in average NPS score: recent period minus earlier period. Negative means sentiment is falling.',
    AVG_ACTIVE_ROBOTS_30D       COMMENT 'Average daily active robots over the last 30 days.',
    AVG_ACTIVE_ROBOTS_PRIOR_90D COMMENT 'Average daily active robots over the 90 days before the last 30 (days 31-120).',
    UTILIZATION_PCT_30D         COMMENT 'Average daily active robots over the last 30 days as a percentage of TOTAL_ROBOTS.',
    USAGE_TREND_PCT             COMMENT 'Percent change in average daily active robots, last 30 days versus the prior 90 days. Negative means declining adoption.',
    OPERATING_HOURS_30D         COMMENT 'Total robot operating hours over the last 30 days.',
    MISSIONS_30D                COMMENT 'Missions completed over the last 30 days.',
    AUTONOMY_PCT_30D            COMMENT 'Average autonomy rate (percent of time operating autonomously) over the last 30 days.',
    LAST_USAGE_DATE             COMMENT 'Most recent day with recorded usage.',
    LATE_PAYMENT_PCT_12M        COMMENT 'Percentage of invoices in the last 12 months that were paid late or are overdue (0-100).',
    OVERDUE_AMOUNT_USD          COMMENT 'Total amount of invoices currently Overdue in the last 12 months, US dollars.',
    AVG_DAYS_LATE_12M           COMMENT 'Average days late across invoices in the last 12 months.',
    OPEN_PIPELINE_USD           COMMENT 'Total amount of open (not closed) opportunities, US dollars, including renewals.',
    OPEN_EXPANSION_PIPELINE_USD COMMENT 'Total amount of open non-renewal opportunities (Expansion, Upsell, New Site, Services), US dollars.',
    EXPANSION_WON_12M_USD       COMMENT 'Value of non-renewal opportunities won in the last 12 months, US dollars.',
    EXPANSION_WINS_12M          COMMENT 'Number of non-renewal opportunities won in the last 12 months.',
    RENEWAL_STAGE               COMMENT 'Sales stage of the open renewal opportunity, if any.',
    RENEWAL_PROBABILITY_PCT     COMMENT 'Win probability of the open renewal opportunity, percent.',
    INTERACTIONS_90D            COMMENT 'Customer interactions in the 90 days before the as-of / snapshot date.',
    NEGATIVE_SENTIMENT_PCT_90D  COMMENT 'Percentage of interactions in the last 90 days with Negative sentiment (0-100).',
    LAST_INTERACTION_DATE       COMMENT 'Date of the most recent interaction.',
    LAST_INTERACTION_TYPE       COMMENT 'Type of the most recent interaction.',
    DAYS_SINCE_LAST_INTERACTION COMMENT 'Days from the last interaction to the as-of date.',
    CHURN_RISK_SCORE            COMMENT 'Predicted probability (0-1) that the customer churns within 180 days, from the BD_CHURN_RISK XGBoost model.',
    CHURN_RISK_TIER             COMMENT 'Churn risk band from CHURN_RISK_SCORE: High (above 0.6), Medium (0.3-0.6) or Low (0.3 or below).',
    HEALTH_SCORE                COMMENT 'Customer health score 0-100 from the BD_CUSTOMER_HEALTH_SCORE model; higher is healthier.',
    HEALTH_BAND                 COMMENT 'Health band from HEALTH_SCORE: Healthy (75 or more), Monitor (50-75) or At Risk (below 50).',
    EXPANSION_PROPENSITY        COMMENT 'Predicted probability (0-1) that the customer wins an expansion within 180 days, from the BD_EXPANSION_PROPENSITY model.',
    EXPANSION_TIER              COMMENT 'Expansion band from EXPANSION_PROPENSITY: High (above 0.6), Medium (0.3-0.6) or Low (0.3 or below).',
    TOP_RISK_DRIVERS            COMMENT 'Features pushing churn risk up most for this customer (SHAP contributions), or ''No significant risk drivers''.',
    ML_SCORED_AT                COMMENT 'Timestamp the ML scores were produced.'
)
COMMENT = 'Customer 360: one row per customer combining firmographics, contracts and ARR, renewals, fleet, incidents, support, NPS, usage, billing, pipeline, interaction sentiment and ML scores. Rolling windows (30/90/180/365 days) end at AS_OF_DATE (today, or the churn date for churned customers). Source for BD_CUSTOMER_360_SV and the Customer 360 agent UDFs.'
-- @cols-end
AS
WITH base AS (
    SELECT c.*,
        IFF(c.LIFECYCLE_STAGE = 'Churned', c.CONTRACT_END_DATE, CURRENT_DATE()) AS AS_OF_DATE
    FROM BD_INTELLIGENCE.RAW.CUSTOMERS c
),
fleet AS (
    SELECT d.CUSTOMER_ID,
        COUNT(DISTINCT d.DEPLOYMENT_ID) AS SITE_COUNT,
        COUNT(r.ROBOT_ID) AS TOTAL_ROBOTS,
        COUNT_IF(r.STATUS = 'Active') AS ACTIVE_ROBOTS,
        COUNT_IF(r.ROBOT_MODEL = 'Atlas') AS ATLAS_COUNT,
        COUNT_IF(r.ROBOT_MODEL = 'Spot') AS SPOT_COUNT,
        COUNT_IF(r.ROBOT_MODEL = 'Stretch') AS STRETCH_COUNT
    FROM BD_INTELLIGENCE.RAW.DEPLOYMENTS d
    LEFT JOIN BD_INTELLIGENCE.RAW.ROBOTS r ON r.DEPLOYMENT_ID = d.DEPLOYMENT_ID
    GROUP BY d.CUSTOMER_ID
),
contracts AS (
    SELECT CUSTOMER_ID,
        SUM(IFF(STATUS = 'Active', ARR_USD, 0)) AS CURRENT_ARR_USD,
        SUM(IFF(STATUS = 'Churned', ARR_USD, 0)) AS CHURNED_ARR_USD,
        SUM(TCV_USD) AS LIFETIME_CONTRACT_VALUE_USD,
        COUNT(*) AS CONTRACT_COUNT,
        COUNT_IF(STATUS = 'Renewed') AS RENEWAL_COUNT,
        MAX(IFF(CONTRACT_TYPE <> 'Expansion', CONTRACT_TYPE, NULL)) AS PRIMARY_CONTRACT_TYPE,
        MAX(PRODUCT_LINE) AS PRIMARY_PRODUCT_LINE,
        BOOLOR_AGG(IFF(STATUS = 'Active', AUTO_RENEW, FALSE)) AS AUTO_RENEW
    FROM BD_INTELLIGENCE.RAW.CONTRACTS
    GROUP BY CUSTOMER_ID
),
incidents AS (
    SELECT d.CUSTOMER_ID,
        COUNT(*) AS INCIDENTS_90D,
        COUNT_IF(i.SEVERITY = 'Critical') AS CRITICAL_INCIDENTS_90D,
        SUM(i.DOWNTIME_MINUTES) AS DOWNTIME_MINUTES_90D
    FROM BD_INTELLIGENCE.RAW.INCIDENTS i
    JOIN BD_INTELLIGENCE.RAW.DEPLOYMENTS d ON d.DEPLOYMENT_ID = i.DEPLOYMENT_ID
    JOIN base b ON b.CUSTOMER_ID = d.CUSTOMER_ID
    WHERE i.REPORTED_AT >= DATEADD(DAY, -90, b.AS_OF_DATE)
    GROUP BY d.CUSTOMER_ID
),
tickets AS (
    SELECT t.CUSTOMER_ID,
        COUNT(*) AS TICKETS_90D,
        COUNT_IF(t.PRIORITY IN ('Critical','High')) AS HIGH_PRIORITY_TICKETS_90D,
        COUNT_IF(t.STATUS = 'Open') AS OPEN_TICKETS,
        ROUND(AVG(IFF(t.SLA_MET, 100, 0)), 1) AS SLA_MET_PCT_90D,
        ROUND(AVG(t.CSAT_SCORE), 2) AS AVG_TICKET_CSAT_90D,
        ROUND(AVG(t.RESOLUTION_HOURS), 1) AS AVG_RESOLUTION_HOURS_90D
    FROM BD_INTELLIGENCE.RAW.SUPPORT_TICKETS t
    JOIN base b ON b.CUSTOMER_ID = t.CUSTOMER_ID
    WHERE t.OPENED_AT >= DATEADD(DAY, -90, b.AS_OF_DATE)
    GROUP BY t.CUSTOMER_ID
),
nps AS (
    SELECT s.CUSTOMER_ID,
        ROUND(AVG(IFF(s.RESPONSE_DATE >= DATEADD(DAY, -180, b.AS_OF_DATE), s.SCORE, NULL)), 1) AS AVG_NPS_6M,
        ROUND(AVG(IFF(s.RESPONSE_DATE <  DATEADD(DAY, -180, b.AS_OF_DATE), s.SCORE, NULL)), 1) AS AVG_NPS_PRIOR_6M,
        MAX_BY(s.SCORE, s.RESPONSE_DATE) AS LATEST_NPS,
        MAX_BY(s.NPS_CATEGORY, s.RESPONSE_DATE) AS LATEST_NPS_CATEGORY
    FROM BD_INTELLIGENCE.RAW.SURVEYS s
    JOIN base b ON b.CUSTOMER_ID = s.CUSTOMER_ID
    WHERE s.SURVEY_TYPE = 'NPS'
    GROUP BY s.CUSTOMER_ID
),
usage AS (
    SELECT u.CUSTOMER_ID,
        ROUND(AVG(IFF(u.USAGE_DATE >  DATEADD(DAY, -30, b.AS_OF_DATE), u.ACTIVE_ROBOTS, NULL)), 1) AS AVG_ACTIVE_ROBOTS_30D,
        ROUND(AVG(IFF(u.USAGE_DATE <= DATEADD(DAY, -30, b.AS_OF_DATE) AND u.USAGE_DATE > DATEADD(DAY, -120, b.AS_OF_DATE), u.ACTIVE_ROBOTS, NULL)), 1) AS AVG_ACTIVE_ROBOTS_PRIOR_90D,
        ROUND(SUM(IFF(u.USAGE_DATE > DATEADD(DAY, -30, b.AS_OF_DATE), u.OPERATING_HOURS, 0)), 0) AS OPERATING_HOURS_30D,
        SUM(IFF(u.USAGE_DATE > DATEADD(DAY, -30, b.AS_OF_DATE), u.MISSIONS_COMPLETED, 0)) AS MISSIONS_30D,
        ROUND(AVG(IFF(u.USAGE_DATE > DATEADD(DAY, -30, b.AS_OF_DATE), u.AUTONOMY_PCT, NULL)), 1) AS AUTONOMY_PCT_30D,
        MAX(u.USAGE_DATE) AS LAST_USAGE_DATE
    FROM BD_INTELLIGENCE.RAW.PRODUCT_USAGE_DAILY u
    JOIN base b ON b.CUSTOMER_ID = u.CUSTOMER_ID
    GROUP BY u.CUSTOMER_ID
),
billing AS (
    SELECT v.CUSTOMER_ID,
        ROUND(AVG(IFF(v.PAYMENT_STATUS IN ('Paid Late','Overdue'), 100, 0)), 1) AS LATE_PAYMENT_PCT_12M,
        ROUND(SUM(IFF(v.PAYMENT_STATUS = 'Overdue', v.AMOUNT_USD, 0)), 2) AS OVERDUE_AMOUNT_USD,
        ROUND(AVG(v.DAYS_LATE), 1) AS AVG_DAYS_LATE_12M
    FROM BD_INTELLIGENCE.RAW.INVOICES v
    JOIN base b ON b.CUSTOMER_ID = v.CUSTOMER_ID
    WHERE v.INVOICE_DATE >= DATEADD(DAY, -365, b.AS_OF_DATE)
    GROUP BY v.CUSTOMER_ID
),
pipeline AS (
    SELECT o.CUSTOMER_ID,
        SUM(IFF(NOT o.IS_CLOSED, o.AMOUNT_USD, 0)) AS OPEN_PIPELINE_USD,
        SUM(IFF(NOT o.IS_CLOSED AND o.OPPORTUNITY_TYPE <> 'Renewal', o.AMOUNT_USD, 0)) AS OPEN_EXPANSION_PIPELINE_USD,
        SUM(IFF(o.IS_WON AND o.OPPORTUNITY_TYPE <> 'Renewal' AND o.CLOSE_DATE >= DATEADD(DAY, -365, b.AS_OF_DATE), o.AMOUNT_USD, 0)) AS EXPANSION_WON_12M_USD,
        COUNT_IF(o.IS_WON AND o.OPPORTUNITY_TYPE <> 'Renewal' AND o.CLOSE_DATE >= DATEADD(DAY, -365, b.AS_OF_DATE)) AS EXPANSION_WINS_12M,
        MAX(IFF(o.OPPORTUNITY_TYPE = 'Renewal' AND NOT o.IS_CLOSED, o.STAGE, NULL)) AS RENEWAL_STAGE,
        MAX(IFF(o.OPPORTUNITY_TYPE = 'Renewal' AND NOT o.IS_CLOSED, o.PROBABILITY_PCT, NULL)) AS RENEWAL_PROBABILITY_PCT
    FROM BD_INTELLIGENCE.RAW.OPPORTUNITIES o
    JOIN base b ON b.CUSTOMER_ID = o.CUSTOMER_ID
    GROUP BY o.CUSTOMER_ID
),
interactions AS (
    SELECT n.CUSTOMER_ID,
        COUNT_IF(n.INTERACTION_DATE >= DATEADD(DAY, -90, b.AS_OF_DATE)) AS INTERACTIONS_90D,
        ROUND(100 * COUNT_IF(n.INTERACTION_DATE >= DATEADD(DAY, -90, b.AS_OF_DATE) AND n.SENTIMENT = 'Negative')
              / NULLIF(COUNT_IF(n.INTERACTION_DATE >= DATEADD(DAY, -90, b.AS_OF_DATE)), 0), 1) AS NEGATIVE_SENTIMENT_PCT_90D,
        MAX(n.INTERACTION_DATE) AS LAST_INTERACTION_DATE,
        MAX_BY(n.INTERACTION_TYPE, n.INTERACTION_DATE) AS LAST_INTERACTION_TYPE
    FROM BD_INTELLIGENCE.RAW.INTERACTIONS n
    JOIN base b ON b.CUSTOMER_ID = n.CUSTOMER_ID
    GROUP BY n.CUSTOMER_ID
)
SELECT
    b.CUSTOMER_ID, b.CUSTOMER_NAME, b.INDUSTRY, b.SEGMENT, b.COMPANY_SIZE, b.REGION, b.COUNTRY, b.HQ_CITY,
    b.ANNUAL_REVENUE_USD, b.EMPLOYEE_COUNT, b.SUPPORT_TIER, b.ACCOUNT_MANAGER, b.CSM_NAME, b.LIFECYCLE_STAGE,
    b.CUSTOMER_SINCE, DATEDIFF(DAY, b.CUSTOMER_SINCE, b.AS_OF_DATE) AS TENURE_DAYS,
    b.CONTRACT_START_DATE, b.CONTRACT_END_DATE,
    IFF(b.LIFECYCLE_STAGE = 'Churned', NULL, DATEDIFF(DAY, CURRENT_DATE(), b.CONTRACT_END_DATE)) AS DAYS_TO_RENEWAL,
    b.AS_OF_DATE,
    COALESCE(f.SITE_COUNT, 0) AS SITE_COUNT, COALESCE(f.TOTAL_ROBOTS, 0) AS TOTAL_ROBOTS,
    COALESCE(f.ACTIVE_ROBOTS, 0) AS ACTIVE_ROBOTS,
    COALESCE(f.ATLAS_COUNT, 0) AS ATLAS_COUNT, COALESCE(f.SPOT_COUNT, 0) AS SPOT_COUNT, COALESCE(f.STRETCH_COUNT, 0) AS STRETCH_COUNT,
    COALESCE(ct.CURRENT_ARR_USD, 0) AS CURRENT_ARR_USD, COALESCE(ct.CHURNED_ARR_USD, 0) AS CHURNED_ARR_USD,
    ct.LIFETIME_CONTRACT_VALUE_USD, ct.CONTRACT_COUNT, ct.RENEWAL_COUNT, ct.PRIMARY_CONTRACT_TYPE, ct.PRIMARY_PRODUCT_LINE, ct.AUTO_RENEW,
    COALESCE(i.INCIDENTS_90D, 0) AS INCIDENTS_90D, COALESCE(i.CRITICAL_INCIDENTS_90D, 0) AS CRITICAL_INCIDENTS_90D,
    COALESCE(i.DOWNTIME_MINUTES_90D, 0) AS DOWNTIME_MINUTES_90D,
    ROUND(COALESCE(i.INCIDENTS_90D, 0) / NULLIF(f.TOTAL_ROBOTS, 0), 2) AS INCIDENTS_PER_ROBOT_90D,
    COALESCE(t.TICKETS_90D, 0) AS TICKETS_90D, COALESCE(t.HIGH_PRIORITY_TICKETS_90D, 0) AS HIGH_PRIORITY_TICKETS_90D,
    COALESCE(t.OPEN_TICKETS, 0) AS OPEN_TICKETS,
    ROUND(COALESCE(t.TICKETS_90D, 0) / NULLIF(f.TOTAL_ROBOTS, 0), 2) AS TICKETS_PER_ROBOT_90D,
    t.SLA_MET_PCT_90D, t.AVG_TICKET_CSAT_90D, t.AVG_RESOLUTION_HOURS_90D,
    np.LATEST_NPS, np.LATEST_NPS_CATEGORY, np.AVG_NPS_6M, np.AVG_NPS_PRIOR_6M,
    ROUND(np.AVG_NPS_6M - np.AVG_NPS_PRIOR_6M, 1) AS NPS_TREND,
    u.AVG_ACTIVE_ROBOTS_30D, u.AVG_ACTIVE_ROBOTS_PRIOR_90D,
    ROUND(100 * u.AVG_ACTIVE_ROBOTS_30D / NULLIF(f.TOTAL_ROBOTS, 0), 1) AS UTILIZATION_PCT_30D,
    ROUND(100 * (u.AVG_ACTIVE_ROBOTS_30D - u.AVG_ACTIVE_ROBOTS_PRIOR_90D) / NULLIF(u.AVG_ACTIVE_ROBOTS_PRIOR_90D, 0), 1) AS USAGE_TREND_PCT,
    u.OPERATING_HOURS_30D, u.MISSIONS_30D, u.AUTONOMY_PCT_30D, u.LAST_USAGE_DATE,
    COALESCE(bl.LATE_PAYMENT_PCT_12M, 0) AS LATE_PAYMENT_PCT_12M, COALESCE(bl.OVERDUE_AMOUNT_USD, 0) AS OVERDUE_AMOUNT_USD,
    bl.AVG_DAYS_LATE_12M,
    COALESCE(p.OPEN_PIPELINE_USD, 0) AS OPEN_PIPELINE_USD, COALESCE(p.OPEN_EXPANSION_PIPELINE_USD, 0) AS OPEN_EXPANSION_PIPELINE_USD,
    COALESCE(p.EXPANSION_WON_12M_USD, 0) AS EXPANSION_WON_12M_USD, COALESCE(p.EXPANSION_WINS_12M, 0) AS EXPANSION_WINS_12M,
    p.RENEWAL_STAGE, p.RENEWAL_PROBABILITY_PCT,
    COALESCE(n.INTERACTIONS_90D, 0) AS INTERACTIONS_90D, n.NEGATIVE_SENTIMENT_PCT_90D,
    n.LAST_INTERACTION_DATE, n.LAST_INTERACTION_TYPE,
    DATEDIFF(DAY, n.LAST_INTERACTION_DATE, b.AS_OF_DATE) AS DAYS_SINCE_LAST_INTERACTION,
    ml.CHURN_RISK_SCORE, ml.CHURN_RISK_TIER, ml.HEALTH_SCORE, ml.HEALTH_BAND,
    ml.EXPANSION_PROPENSITY, ml.EXPANSION_TIER, ml.TOP_RISK_DRIVERS, ml.SCORED_AT AS ML_SCORED_AT
FROM base b
LEFT JOIN fleet f        ON f.CUSTOMER_ID = b.CUSTOMER_ID
LEFT JOIN contracts ct   ON ct.CUSTOMER_ID = b.CUSTOMER_ID
LEFT JOIN incidents i    ON i.CUSTOMER_ID = b.CUSTOMER_ID
LEFT JOIN tickets t      ON t.CUSTOMER_ID = b.CUSTOMER_ID
LEFT JOIN nps np         ON np.CUSTOMER_ID = b.CUSTOMER_ID
LEFT JOIN usage u        ON u.CUSTOMER_ID = b.CUSTOMER_ID
LEFT JOIN billing bl     ON bl.CUSTOMER_ID = b.CUSTOMER_ID
LEFT JOIN pipeline p     ON p.CUSTOMER_ID = b.CUSTOMER_ID
LEFT JOIN interactions n ON n.CUSTOMER_ID = b.CUSTOMER_ID
LEFT JOIN BD_INTELLIGENCE.ANALYTICS.CUSTOMER_ML_SCORES ml ON ml.CUSTOMER_ID = b.CUSTOMER_ID;

-- ----------------------------------------------------------------------------
-- Customer ML Features: point-in-time feature snapshots for the customer
-- models. SNAPSHOT_K = 0 is the scoring row at each customer's as-of date
-- (today, or churn date for churned). SNAPSHOT_K = 1..9 step back 30 days at
-- a time and carry forward-looking labels for training. Labels are NULL when
-- the 180-day outcome window has not fully elapsed.
-- Grain: CUSTOMER_ID, SNAPSHOT_K
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW CUSTOMER_ML_FEATURES
-- @cols-begin
(
    CUSTOMER_ID                COMMENT 'Customer account identifier (CUST-0000 format). Joins to RAW.CUSTOMERS.',
    SNAPSHOT_K                 COMMENT 'Snapshot index: 0 is the scoring row at the as-of date; 1-9 are training snapshots 30, 60 ... 270 days earlier.',
    SNAPSHOT_DATE              COMMENT 'Point-in-time date the features are computed as of. All windows end on this date, so there is no look-ahead.',
    LIFECYCLE_STAGE            COMMENT 'Account lifecycle stage: Onboarding, Adopting, Mature, Renewal Due or Churned. Churned accounts have no active contract.',
    IS_SCORING_ROW             COMMENT 'TRUE for SNAPSHOT_K = 0, the row used for current scoring (no label).',
    TENURE_DAYS                COMMENT 'Days from CUSTOMER_SINCE to SNAPSHOT_DATE.',
    TOTAL_ROBOTS               COMMENT 'Number of robots deployed across the customer''s sites.',
    SITE_COUNT                 COMMENT 'Number of deployment sites for the customer.',
    INCIDENTS_PER_ROBOT_90D    COMMENT 'Incidents in the 90 days before SNAPSHOT_DATE divided by TOTAL_ROBOTS.',
    CRITICAL_INCIDENTS_90D     COMMENT 'Critical-severity incidents in the 90 days before the as-of / snapshot date.',
    TICKETS_PER_ROBOT_90D      COMMENT 'Tickets opened in the 90 days before SNAPSHOT_DATE divided by TOTAL_ROBOTS.',
    HIGH_PRIORITY_TICKETS_90D  COMMENT 'Critical or High priority tickets opened in the 90 days before the as-of / snapshot date.',
    SLA_MET_PCT_90D            COMMENT 'Percentage of tickets opened in the 90 days before SNAPSHOT_DATE and closed by then that met SLA.',
    AVG_TICKET_CSAT_90D        COMMENT 'Average CSAT of tickets opened in the 90 days before SNAPSHOT_DATE and closed by then.',
    AVG_RESOLUTION_HOURS_90D   COMMENT 'Average resolution hours of tickets opened in the 90 days before SNAPSHOT_DATE and closed by then.',
    AVG_NPS_6M                 COMMENT 'Average NPS score (0-10, not the -100 to +100 index) over the 180 days before the as-of / snapshot date.',
    NPS_TREND                  COMMENT 'Average NPS in the 90 days before SNAPSHOT_DATE minus average NPS in the 90 days before that.',
    UTILIZATION_PCT_30D        COMMENT 'Average daily active robots in the 30 days before SNAPSHOT_DATE as a percentage of TOTAL_ROBOTS.',
    USAGE_TREND_PCT            COMMENT 'Percent change in average daily active robots, 30 days before SNAPSHOT_DATE versus the 90 days before that.',
    AUTONOMY_PCT_30D           COMMENT 'Average autonomy rate in the 30 days before SNAPSHOT_DATE.',
    LATE_PAYMENT_PCT_12M       COMMENT 'Percentage of invoices due in the 12 months before SNAPSHOT_DATE that were paid late.',
    AVG_DAYS_LATE_12M          COMMENT 'Average days late of invoices due in the 12 months before SNAPSHOT_DATE.',
    NEGATIVE_SENTIMENT_PCT_90D COMMENT 'Percentage of interactions in the 90 days before SNAPSHOT_DATE with Negative sentiment.',
    INTERACTIONS_90D           COMMENT 'Customer interactions in the 90 days before the as-of / snapshot date.',
    CHURN_NEXT_180D            COMMENT 'Training label: 1 if the customer churned within 180 days after SNAPSHOT_DATE, 0 if not, NULL for the scoring row or when the 180-day window has not elapsed.',
    EXPANSION_NEXT_180D        COMMENT 'Training label: 1 if a non-renewal opportunity was won within 180 days after SNAPSHOT_DATE, 0 if not, NULL for the scoring row or when the window has not elapsed.'
)
COMMENT = 'Point-in-time training and scoring features for the customer ML models. Grain is CUSTOMER_ID + SNAPSHOT_K. SNAPSHOT_K = 0 is the scoring row at the as-of date; 1-9 step back 30 days each and carry 180-day forward churn and expansion labels (NULL until the outcome window has elapsed). Used by notebooks/07_ml_models.'
-- @cols-end
AS
WITH base AS (
    SELECT c.CUSTOMER_ID, c.CUSTOMER_SINCE, c.LIFECYCLE_STAGE,
        IFF(c.LIFECYCLE_STAGE = 'Churned', c.CONTRACT_END_DATE, NULL) AS CHURN_DATE,
        IFF(c.LIFECYCLE_STAGE = 'Churned', c.CONTRACT_END_DATE, CURRENT_DATE()) AS AS_OF_DATE
    FROM BD_INTELLIGENCE.RAW.CUSTOMERS c
),
snap AS (
    SELECT b.*, k.SNAPSHOT_K,
        DATEADD(DAY, -30 * k.SNAPSHOT_K - IFF(b.CHURN_DATE IS NOT NULL, 1, 0), b.AS_OF_DATE) AS SNAPSHOT_DATE
    FROM base b
    CROSS JOIN (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS SNAPSHOT_K FROM TABLE(GENERATOR(ROWCOUNT => 10))) k
),
fleet AS (
    SELECT d.CUSTOMER_ID, COUNT(DISTINCT d.DEPLOYMENT_ID) AS SITE_COUNT, COUNT(r.ROBOT_ID) AS TOTAL_ROBOTS
    FROM BD_INTELLIGENCE.RAW.DEPLOYMENTS d
    LEFT JOIN BD_INTELLIGENCE.RAW.ROBOTS r ON r.DEPLOYMENT_ID = d.DEPLOYMENT_ID
    GROUP BY d.CUSTOMER_ID
),
tickets AS (
    SELECT s.CUSTOMER_ID, s.SNAPSHOT_K,
        COUNT(t.TICKET_ID) AS TICKETS_90D,
        COUNT_IF(t.PRIORITY IN ('Critical','High')) AS HIGH_PRIORITY_TICKETS_90D,
        AVG(IFF(t.CLOSED_AT <= s.SNAPSHOT_DATE, IFF(t.SLA_MET, 100, 0), NULL)) AS SLA_MET_PCT_90D,
        AVG(IFF(t.CLOSED_AT <= s.SNAPSHOT_DATE, t.CSAT_SCORE, NULL)) AS AVG_TICKET_CSAT_90D,
        AVG(IFF(t.CLOSED_AT <= s.SNAPSHOT_DATE, t.RESOLUTION_HOURS, NULL)) AS AVG_RESOLUTION_HOURS_90D
    FROM snap s
    LEFT JOIN BD_INTELLIGENCE.RAW.SUPPORT_TICKETS t
        ON t.CUSTOMER_ID = s.CUSTOMER_ID
       AND t.OPENED_AT > DATEADD(DAY, -90, s.SNAPSHOT_DATE) AND t.OPENED_AT <= s.SNAPSHOT_DATE
    GROUP BY s.CUSTOMER_ID, s.SNAPSHOT_K
),
incidents AS (
    SELECT s.CUSTOMER_ID, s.SNAPSHOT_K,
        COUNT(i.INCIDENT_ID) AS INCIDENTS_90D,
        COUNT_IF(i.SEVERITY = 'Critical') AS CRITICAL_INCIDENTS_90D
    FROM snap s
    LEFT JOIN BD_INTELLIGENCE.RAW.DEPLOYMENTS d ON d.CUSTOMER_ID = s.CUSTOMER_ID
    LEFT JOIN BD_INTELLIGENCE.RAW.INCIDENTS i
        ON i.DEPLOYMENT_ID = d.DEPLOYMENT_ID
       AND i.REPORTED_AT > DATEADD(DAY, -90, s.SNAPSHOT_DATE) AND i.REPORTED_AT <= s.SNAPSHOT_DATE
    GROUP BY s.CUSTOMER_ID, s.SNAPSHOT_K
),
nps AS (
    SELECT s.CUSTOMER_ID, s.SNAPSHOT_K,
        AVG(v.SCORE) AS AVG_NPS_6M,
        AVG(IFF(v.RESPONSE_DATE >  DATEADD(DAY, -90, s.SNAPSHOT_DATE), v.SCORE, NULL))
          - AVG(IFF(v.RESPONSE_DATE <= DATEADD(DAY, -90, s.SNAPSHOT_DATE), v.SCORE, NULL)) AS NPS_TREND
    FROM snap s
    LEFT JOIN BD_INTELLIGENCE.RAW.SURVEYS v
        ON v.CUSTOMER_ID = s.CUSTOMER_ID AND v.SURVEY_TYPE = 'NPS'
       AND v.RESPONSE_DATE > DATEADD(DAY, -180, s.SNAPSHOT_DATE) AND v.RESPONSE_DATE <= s.SNAPSHOT_DATE
    GROUP BY s.CUSTOMER_ID, s.SNAPSHOT_K
),
usage AS (
    SELECT s.CUSTOMER_ID, s.SNAPSHOT_K,
        AVG(IFF(u.USAGE_DATE >  DATEADD(DAY, -30, s.SNAPSHOT_DATE), u.ACTIVE_ROBOTS, NULL)) AS ACTIVE_30D,
        AVG(IFF(u.USAGE_DATE <= DATEADD(DAY, -30, s.SNAPSHOT_DATE), u.ACTIVE_ROBOTS, NULL)) AS ACTIVE_PRIOR_90D,
        AVG(IFF(u.USAGE_DATE >  DATEADD(DAY, -30, s.SNAPSHOT_DATE), u.AUTONOMY_PCT, NULL)) AS AUTONOMY_PCT_30D
    FROM snap s
    LEFT JOIN BD_INTELLIGENCE.RAW.PRODUCT_USAGE_DAILY u
        ON u.CUSTOMER_ID = s.CUSTOMER_ID
       AND u.USAGE_DATE > DATEADD(DAY, -120, s.SNAPSHOT_DATE) AND u.USAGE_DATE <= s.SNAPSHOT_DATE
    GROUP BY s.CUSTOMER_ID, s.SNAPSHOT_K
),
billing AS (
    SELECT s.CUSTOMER_ID, s.SNAPSHOT_K,
        AVG(IFF(v.DAYS_LATE > 0, 100, 0)) AS LATE_PAYMENT_PCT_12M,
        AVG(v.DAYS_LATE) AS AVG_DAYS_LATE_12M
    FROM snap s
    LEFT JOIN BD_INTELLIGENCE.RAW.INVOICES v
        ON v.CUSTOMER_ID = s.CUSTOMER_ID
       AND v.DUE_DATE > DATEADD(DAY, -365, s.SNAPSHOT_DATE) AND v.DUE_DATE <= s.SNAPSHOT_DATE
    GROUP BY s.CUSTOMER_ID, s.SNAPSHOT_K
),
interactions AS (
    SELECT s.CUSTOMER_ID, s.SNAPSHOT_K,
        COUNT(n.INTERACTION_ID) AS INTERACTIONS_90D,
        100 * COUNT_IF(n.SENTIMENT = 'Negative') / NULLIF(COUNT(n.INTERACTION_ID), 0) AS NEGATIVE_SENTIMENT_PCT_90D
    FROM snap s
    LEFT JOIN BD_INTELLIGENCE.RAW.INTERACTIONS n
        ON n.CUSTOMER_ID = s.CUSTOMER_ID
       AND n.INTERACTION_DATE > DATEADD(DAY, -90, s.SNAPSHOT_DATE) AND n.INTERACTION_DATE <= s.SNAPSHOT_DATE
    GROUP BY s.CUSTOMER_ID, s.SNAPSHOT_K
),
expansion AS (
    SELECT s.CUSTOMER_ID, s.SNAPSHOT_K, COUNT(o.OPPORTUNITY_ID) AS EXPANSION_WINS_NEXT_180D
    FROM snap s
    LEFT JOIN BD_INTELLIGENCE.RAW.OPPORTUNITIES o
        ON o.CUSTOMER_ID = s.CUSTOMER_ID AND o.IS_WON AND o.OPPORTUNITY_TYPE <> 'Renewal'
       AND o.CLOSE_DATE > s.SNAPSHOT_DATE AND o.CLOSE_DATE <= DATEADD(DAY, 180, s.SNAPSHOT_DATE)
    GROUP BY s.CUSTOMER_ID, s.SNAPSHOT_K
)
SELECT
    s.CUSTOMER_ID, s.SNAPSHOT_K, s.SNAPSHOT_DATE, s.LIFECYCLE_STAGE,
    s.SNAPSHOT_K = 0 AS IS_SCORING_ROW,
    DATEDIFF(DAY, s.CUSTOMER_SINCE, s.SNAPSHOT_DATE) AS TENURE_DAYS,
    f.TOTAL_ROBOTS, f.SITE_COUNT,
    ROUND(i.INCIDENTS_90D / NULLIF(f.TOTAL_ROBOTS, 0), 3) AS INCIDENTS_PER_ROBOT_90D,
    i.CRITICAL_INCIDENTS_90D,
    ROUND(t.TICKETS_90D / NULLIF(f.TOTAL_ROBOTS, 0), 3) AS TICKETS_PER_ROBOT_90D,
    t.HIGH_PRIORITY_TICKETS_90D, t.SLA_MET_PCT_90D, t.AVG_TICKET_CSAT_90D, t.AVG_RESOLUTION_HOURS_90D,
    np.AVG_NPS_6M, np.NPS_TREND,
    ROUND(100 * u.ACTIVE_30D / NULLIF(f.TOTAL_ROBOTS, 0), 2) AS UTILIZATION_PCT_30D,
    ROUND(100 * (u.ACTIVE_30D - u.ACTIVE_PRIOR_90D) / NULLIF(u.ACTIVE_PRIOR_90D, 0), 2) AS USAGE_TREND_PCT,
    u.AUTONOMY_PCT_30D,
    bl.LATE_PAYMENT_PCT_12M, bl.AVG_DAYS_LATE_12M,
    n.NEGATIVE_SENTIMENT_PCT_90D, n.INTERACTIONS_90D,
    -- Labels (NULL until the 180-day outcome window has elapsed)
    CASE WHEN s.SNAPSHOT_K = 0 THEN NULL
         WHEN s.CHURN_DATE IS NOT NULL AND s.CHURN_DATE > s.SNAPSHOT_DATE
              AND s.CHURN_DATE <= DATEADD(DAY, 180, s.SNAPSHOT_DATE) THEN 1
         WHEN DATEADD(DAY, 180, s.SNAPSHOT_DATE) <= LEAST(CURRENT_DATE(), COALESCE(s.CHURN_DATE, CURRENT_DATE())) THEN 0
         ELSE NULL END AS CHURN_NEXT_180D,
    CASE WHEN s.SNAPSHOT_K = 0 THEN NULL
         WHEN e.EXPANSION_WINS_NEXT_180D > 0 THEN 1
         WHEN DATEADD(DAY, 180, s.SNAPSHOT_DATE) <= CURRENT_DATE() THEN 0
         ELSE NULL END AS EXPANSION_NEXT_180D
FROM snap s
LEFT JOIN fleet f        ON f.CUSTOMER_ID = s.CUSTOMER_ID
LEFT JOIN tickets t      ON t.CUSTOMER_ID = s.CUSTOMER_ID AND t.SNAPSHOT_K = s.SNAPSHOT_K
LEFT JOIN incidents i    ON i.CUSTOMER_ID = s.CUSTOMER_ID AND i.SNAPSHOT_K = s.SNAPSHOT_K
LEFT JOIN nps np         ON np.CUSTOMER_ID = s.CUSTOMER_ID AND np.SNAPSHOT_K = s.SNAPSHOT_K
LEFT JOIN usage u        ON u.CUSTOMER_ID = s.CUSTOMER_ID AND u.SNAPSHOT_K = s.SNAPSHOT_K
LEFT JOIN billing bl     ON bl.CUSTOMER_ID = s.CUSTOMER_ID AND bl.SNAPSHOT_K = s.SNAPSHOT_K
LEFT JOIN interactions n ON n.CUSTOMER_ID = s.CUSTOMER_ID AND n.SNAPSHOT_K = s.SNAPSHOT_K
LEFT JOIN expansion e    ON e.CUSTOMER_ID = s.CUSTOMER_ID AND e.SNAPSHOT_K = s.SNAPSHOT_K
WHERE s.SNAPSHOT_DATE >= s.CUSTOMER_SINCE;

-- ----------------------------------------------------------------------------
-- Customer Revenue Monthly: invoiced, paid, late and overdue per customer-month
-- Grain: CUSTOMER_ID, REVENUE_MONTH
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW CUSTOMER_REVENUE_MONTHLY
-- @cols-begin
(
    CUSTOMER_ID        COMMENT 'Customer account identifier (CUST-0000 format). Joins to RAW.CUSTOMERS.',
    REVENUE_MONTH      COMMENT 'First day of the invoice month.',
    CUSTOMER_NAME      COMMENT 'Customer company name (for example Siemens Energy, Tesla Gigafactory).',
    INDUSTRY           COMMENT 'Customer industry: Automotive Manufacturing, Logistics & Warehousing, Energy & Utilities, Aerospace & Defense, Industrial Manufacturing or Mining & Resources.',
    SEGMENT            COMMENT 'Go-to-market segment based on annual revenue: Strategic (largest), Enterprise or Commercial.',
    REGION             COMMENT 'Customer headquarters region: North America, Europe, Asia Pacific, South America or Middle East & Africa.',
    ACCOUNT_MANAGER    COMMENT 'Boston Dynamics account executive who owns the commercial relationship.',
    LIFECYCLE_STAGE    COMMENT 'Account lifecycle stage: Onboarding, Adopting, Mature, Renewal Due or Churned. Churned accounts have no active contract.',
    INVOICE_COUNT      COMMENT 'Number of invoices issued in the month.',
    INVOICED_USD       COMMENT 'Total amount invoiced in the month, US dollars.',
    COLLECTED_USD      COMMENT 'Amount from the month''s invoices that has been paid (on time or late), US dollars.',
    PAID_LATE_USD      COMMENT 'Amount from the month''s invoices that was paid after the due date, US dollars.',
    OVERDUE_USD        COMMENT 'Amount from the month''s invoices that is past due and unpaid, US dollars.',
    OPEN_USD           COMMENT 'Amount from the month''s invoices that is unpaid but not yet due, US dollars.',
    LATE_INVOICE_COUNT COMMENT 'Number of the month''s invoices that were paid late or are overdue.',
    AVG_DAYS_LATE      COMMENT 'Average days late across the month''s invoices.'
)
COMMENT = 'Billing and collections per customer per invoice month: invoiced, collected, paid late, overdue and open amounts, with late-invoice counts. Source for BD_REVENUE_SV.'
-- @cols-end
AS
SELECT
    v.CUSTOMER_ID,
    DATE_TRUNC('MONTH', v.INVOICE_DATE)::DATE AS REVENUE_MONTH,
    c.CUSTOMER_NAME, c.INDUSTRY, c.SEGMENT, c.REGION, c.ACCOUNT_MANAGER, c.LIFECYCLE_STAGE,
    COUNT(*) AS INVOICE_COUNT,
    ROUND(SUM(v.AMOUNT_USD), 2) AS INVOICED_USD,
    ROUND(SUM(IFF(v.PAYMENT_STATUS IN ('Paid','Paid Late'), v.AMOUNT_USD, 0)), 2) AS COLLECTED_USD,
    ROUND(SUM(IFF(v.PAYMENT_STATUS = 'Paid Late', v.AMOUNT_USD, 0)), 2) AS PAID_LATE_USD,
    ROUND(SUM(IFF(v.PAYMENT_STATUS = 'Overdue', v.AMOUNT_USD, 0)), 2) AS OVERDUE_USD,
    ROUND(SUM(IFF(v.PAYMENT_STATUS = 'Open', v.AMOUNT_USD, 0)), 2) AS OPEN_USD,
    COUNT_IF(v.PAYMENT_STATUS IN ('Paid Late','Overdue')) AS LATE_INVOICE_COUNT,
    ROUND(AVG(v.DAYS_LATE), 1) AS AVG_DAYS_LATE
FROM BD_INTELLIGENCE.RAW.INVOICES v
JOIN BD_INTELLIGENCE.RAW.CUSTOMERS c ON c.CUSTOMER_ID = v.CUSTOMER_ID
GROUP BY v.CUSTOMER_ID, DATE_TRUNC('MONTH', v.INVOICE_DATE)::DATE,
         c.CUSTOMER_NAME, c.INDUSTRY, c.SEGMENT, c.REGION, c.ACCOUNT_MANAGER, c.LIFECYCLE_STAGE;

-- ----------------------------------------------------------------------------
-- Support Ticket Analysis: one row per ticket with customer context
-- Grain: TICKET_ID
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW SUPPORT_TICKET_ANALYSIS
-- @cols-begin
(
    TICKET_ID        COMMENT 'Support ticket identifier. Primary key of RAW.SUPPORT_TICKETS.',
    CUSTOMER_ID      COMMENT 'Customer account identifier (CUST-0000 format). Joins to RAW.CUSTOMERS.',
    CUSTOMER_NAME    COMMENT 'Customer company name (for example Siemens Energy, Tesla Gigafactory).',
    INDUSTRY         COMMENT 'Customer industry: Automotive Manufacturing, Logistics & Warehousing, Energy & Utilities, Aerospace & Defense, Industrial Manufacturing or Mining & Resources.',
    SEGMENT          COMMENT 'Go-to-market segment based on annual revenue: Strategic (largest), Enterprise or Commercial.',
    REGION           COMMENT 'Customer headquarters region: North America, Europe, Asia Pacific, South America or Middle East & Africa.',
    SUPPORT_TIER     COMMENT 'Purchased support entitlement: Platinum, Gold, Silver or Bronze. Higher tiers have tighter SLAs.',
    CSM_NAME         COMMENT 'Customer Success Manager assigned to the account.',
    ROBOT_ID         COMMENT 'Robot the ticket relates to. Currently NULL on every ticket (not populated in the source data).',
    ROBOT_MODEL      COMMENT 'Model of the robot the ticket relates to. Currently NULL because ROBOT_ID is not populated on tickets.',
    CATEGORY         COMMENT 'Ticket category: Hardware, Software, Navigation, Battery, Connectivity, Integration, Training or Billing.',
    PRIORITY         COMMENT 'Ticket priority: Critical, High, Medium or Low. Drives the SLA target.',
    CHANNEL          COMMENT 'Channel the ticket was raised through: Portal, Email, Phone or Field Engineer.',
    STATUS           COMMENT 'Ticket status: Open or Closed.',
    SUBJECT          COMMENT 'Short ticket subject line.',
    ASSIGNED_TO      COMMENT 'Support engineer who owns the ticket.',
    OPENED_AT        COMMENT 'Timestamp the ticket was opened.',
    OPENED_MONTH     COMMENT 'First day of the month the ticket was opened.',
    CLOSED_AT        COMMENT 'Timestamp the ticket was closed; NULL while open.',
    RESOLUTION_HOURS COMMENT 'Hours from open to close; NULL while open.',
    SLA_MET          COMMENT 'TRUE if the ticket was resolved within the SLA for its priority and the customer''s support tier.',
    CSAT_SCORE       COMMENT 'Customer satisfaction rating for the ticket, 1 (very dissatisfied) to 5 (very satisfied); NULL if not rated.'
)
COMMENT = 'One row per support ticket enriched with customer and robot context, for volume, SLA, resolution-time and CSAT analysis. Source for BD_SUPPORT_SV.'
-- @cols-end
AS
SELECT
    t.TICKET_ID, t.CUSTOMER_ID, c.CUSTOMER_NAME, c.INDUSTRY, c.SEGMENT, c.REGION, c.SUPPORT_TIER, c.CSM_NAME,
    t.ROBOT_ID, r.ROBOT_MODEL,
    t.CATEGORY, t.PRIORITY, t.CHANNEL, t.STATUS, t.SUBJECT, t.ASSIGNED_TO,
    t.OPENED_AT, DATE_TRUNC('MONTH', t.OPENED_AT)::DATE AS OPENED_MONTH, t.CLOSED_AT,
    t.RESOLUTION_HOURS, t.SLA_MET, t.CSAT_SCORE
FROM BD_INTELLIGENCE.RAW.SUPPORT_TICKETS t
JOIN BD_INTELLIGENCE.RAW.CUSTOMERS c ON c.CUSTOMER_ID = t.CUSTOMER_ID
LEFT JOIN BD_INTELLIGENCE.RAW.ROBOTS r ON r.ROBOT_ID = t.ROBOT_ID;

-- ----------------------------------------------------------------------------
-- Customer Usage Trend: monthly product adoption per customer
-- Grain: CUSTOMER_ID, USAGE_MONTH
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW CUSTOMER_USAGE_TREND
-- @cols-begin
(
    CUSTOMER_ID        COMMENT 'Customer account identifier (CUST-0000 format). Joins to RAW.CUSTOMERS.',
    USAGE_MONTH        COMMENT 'First day of the usage month.',
    CUSTOMER_NAME      COMMENT 'Customer company name (for example Siemens Energy, Tesla Gigafactory).',
    INDUSTRY           COMMENT 'Customer industry: Automotive Manufacturing, Logistics & Warehousing, Energy & Utilities, Aerospace & Defense, Industrial Manufacturing or Mining & Resources.',
    SEGMENT            COMMENT 'Go-to-market segment based on annual revenue: Strategic (largest), Enterprise or Commercial.',
    REGION             COMMENT 'Customer headquarters region: North America, Europe, Asia Pacific, South America or Middle East & Africa.',
    LIFECYCLE_STAGE    COMMENT 'Account lifecycle stage: Onboarding, Adopting, Mature, Renewal Due or Churned. Churned accounts have no active contract.',
    TOTAL_ROBOTS       COMMENT 'Number of robots deployed across the customer''s sites.',
    DAYS_REPORTED      COMMENT 'Number of days in the month with usage data.',
    AVG_ACTIVE_ROBOTS  COMMENT 'Average daily active robots in the month.',
    UTILIZATION_PCT    COMMENT 'Average daily active robots as a percentage of the customer''s total robots.',
    OPERATING_HOURS    COMMENT 'Total robot operating hours in the month.',
    MISSIONS_COMPLETED COMMENT 'Total missions completed in the month.',
    AVG_AUTONOMY_PCT   COMMENT 'Average daily autonomy rate in the month, percent.',
    AVG_FEATURES_USED  COMMENT 'Average number of distinct features used per day in the month.',
    APP_LOGINS         COMMENT 'Total fleet app logins in the month.'
)
COMMENT = 'Product adoption per customer per month: average active robots, utilisation against fleet size, operating hours, missions, autonomy, features used and logins. Source for BD_PRODUCT_USAGE_SV.'
-- @cols-end
AS
SELECT
    u.CUSTOMER_ID,
    DATE_TRUNC('MONTH', u.USAGE_DATE)::DATE AS USAGE_MONTH,
    c.CUSTOMER_NAME, c.INDUSTRY, c.SEGMENT, c.REGION, c.LIFECYCLE_STAGE,
    f.TOTAL_ROBOTS,
    COUNT(*) AS DAYS_REPORTED,
    ROUND(AVG(u.ACTIVE_ROBOTS), 1) AS AVG_ACTIVE_ROBOTS,
    ROUND(100 * AVG(u.ACTIVE_ROBOTS) / NULLIF(f.TOTAL_ROBOTS, 0), 1) AS UTILIZATION_PCT,
    ROUND(SUM(u.OPERATING_HOURS), 0) AS OPERATING_HOURS,
    SUM(u.MISSIONS_COMPLETED) AS MISSIONS_COMPLETED,
    ROUND(AVG(u.AUTONOMY_PCT), 1) AS AVG_AUTONOMY_PCT,
    ROUND(AVG(u.FEATURES_USED), 1) AS AVG_FEATURES_USED,
    SUM(u.APP_LOGINS) AS APP_LOGINS
FROM BD_INTELLIGENCE.RAW.PRODUCT_USAGE_DAILY u
JOIN BD_INTELLIGENCE.RAW.CUSTOMERS c ON c.CUSTOMER_ID = u.CUSTOMER_ID
LEFT JOIN (
    SELECT d.CUSTOMER_ID, COUNT(r.ROBOT_ID) AS TOTAL_ROBOTS
    FROM BD_INTELLIGENCE.RAW.DEPLOYMENTS d
    LEFT JOIN BD_INTELLIGENCE.RAW.ROBOTS r ON r.DEPLOYMENT_ID = d.DEPLOYMENT_ID
    GROUP BY d.CUSTOMER_ID
) f ON f.CUSTOMER_ID = u.CUSTOMER_ID
GROUP BY u.CUSTOMER_ID, DATE_TRUNC('MONTH', u.USAGE_DATE)::DATE,
         c.CUSTOMER_NAME, c.INDUSTRY, c.SEGMENT, c.REGION, c.LIFECYCLE_STAGE, f.TOTAL_ROBOTS;

-- ----------------------------------------------------------------------------
-- Sales Pipeline: one row per opportunity with customer context
-- Grain: OPPORTUNITY_ID
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW SALES_PIPELINE
-- @cols-begin
(
    OPPORTUNITY_ID      COMMENT 'Sales opportunity identifier. Primary key of RAW.OPPORTUNITIES.',
    CUSTOMER_ID         COMMENT 'Customer account identifier (CUST-0000 format). Joins to RAW.CUSTOMERS.',
    CUSTOMER_NAME       COMMENT 'Customer company name (for example Siemens Energy, Tesla Gigafactory).',
    INDUSTRY            COMMENT 'Customer industry: Automotive Manufacturing, Logistics & Warehousing, Energy & Utilities, Aerospace & Defense, Industrial Manufacturing or Mining & Resources.',
    SEGMENT             COMMENT 'Go-to-market segment based on annual revenue: Strategic (largest), Enterprise or Commercial.',
    REGION              COMMENT 'Customer headquarters region: North America, Europe, Asia Pacific, South America or Middle East & Africa.',
    LIFECYCLE_STAGE     COMMENT 'Account lifecycle stage: Onboarding, Adopting, Mature, Renewal Due or Churned. Churned accounts have no active contract.',
    OPPORTUNITY_NAME    COMMENT 'Opportunity name: customer, opportunity type and product line.',
    OPPORTUNITY_TYPE    COMMENT 'Opportunity type: Renewal, Expansion, Upsell, New Site or Services.',
    PRODUCT_LINE        COMMENT 'Robot product line covered: Atlas, Spot or Stretch.',
    STAGE               COMMENT 'Sales stage: Discovery, Qualification, Proposal, Negotiation, Commit, Closed Won or Closed Lost.',
    OWNER               COMMENT 'Account executive who owns the opportunity.',
    AMOUNT_USD          COMMENT 'Opportunity value in US dollars.',
    PROBABILITY_PCT     COMMENT 'Win probability in percent for the current stage (0-100; 100 for Closed Won, 0 for Closed Lost).',
    WEIGHTED_AMOUNT_USD COMMENT 'AMOUNT_USD multiplied by PROBABILITY_PCT / 100, US dollars.',
    CREATED_DATE        COMMENT 'Date the opportunity was created.',
    CLOSE_DATE          COMMENT 'Expected close date for open opportunities, actual close date for closed ones.',
    CLOSE_QUARTER       COMMENT 'First day of the calendar quarter of CLOSE_DATE.',
    IS_CLOSED           COMMENT 'TRUE if the opportunity is Closed Won or Closed Lost.',
    IS_WON              COMMENT 'TRUE if the opportunity is Closed Won.',
    LOSS_REASON         COMMENT 'Reason the opportunity was lost: Budget cuts, Insufficient ROI, Moved to competitor, Project cancelled or Unresolved reliability issues. NULL unless Closed Lost.',
    SALES_CYCLE_DAYS    COMMENT 'Days from CREATED_DATE to CLOSE_DATE.'
)
COMMENT = 'One row per opportunity enriched with customer context, weighted amount, close quarter and sales-cycle length. Source for BD_PIPELINE_SV.'
-- @cols-end
AS
SELECT
    o.OPPORTUNITY_ID, o.CUSTOMER_ID, c.CUSTOMER_NAME, c.INDUSTRY, c.SEGMENT, c.REGION, c.LIFECYCLE_STAGE,
    o.OPPORTUNITY_NAME, o.OPPORTUNITY_TYPE, o.PRODUCT_LINE, o.STAGE, o.OWNER,
    o.AMOUNT_USD, o.PROBABILITY_PCT,
    ROUND(o.AMOUNT_USD * o.PROBABILITY_PCT / 100, 2) AS WEIGHTED_AMOUNT_USD,
    o.CREATED_DATE, o.CLOSE_DATE,
    DATE_TRUNC('QUARTER', o.CLOSE_DATE)::DATE AS CLOSE_QUARTER,
    o.IS_CLOSED, o.IS_WON, o.LOSS_REASON,
    DATEDIFF(DAY, o.CREATED_DATE, o.CLOSE_DATE) AS SALES_CYCLE_DAYS
FROM BD_INTELLIGENCE.RAW.OPPORTUNITIES o
JOIN BD_INTELLIGENCE.RAW.CUSTOMERS c ON c.CUSTOMER_ID = o.CUSTOMER_ID;

-- ----------------------------------------------------------------------------
-- Customer Survey Results: one row per NPS / CSAT response
-- Grain: SURVEY_ID
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW CUSTOMER_SURVEY_RESULTS
-- @cols-begin
(
    SURVEY_ID       COMMENT 'Survey response identifier. Primary key of RAW.SURVEYS.',
    CUSTOMER_ID     COMMENT 'Customer account identifier (CUST-0000 format). Joins to RAW.CUSTOMERS.',
    CUSTOMER_NAME   COMMENT 'Customer company name (for example Siemens Energy, Tesla Gigafactory).',
    INDUSTRY        COMMENT 'Customer industry: Automotive Manufacturing, Logistics & Warehousing, Energy & Utilities, Aerospace & Defense, Industrial Manufacturing or Mining & Resources.',
    SEGMENT         COMMENT 'Go-to-market segment based on annual revenue: Strategic (largest), Enterprise or Commercial.',
    REGION          COMMENT 'Customer headquarters region: North America, Europe, Asia Pacific, South America or Middle East & Africa.',
    CSM_NAME        COMMENT 'Customer Success Manager assigned to the account.',
    LIFECYCLE_STAGE COMMENT 'Account lifecycle stage: Onboarding, Adopting, Mature, Renewal Due or Churned. Churned accounts have no active contract.',
    CONTACT_NAME    COMMENT 'Full name of the contact who answered the survey.',
    CONTACT_ROLE    COMMENT 'Buying-group role: Champion, Economic Buyer, Technical User or Procurement.',
    SURVEY_TYPE     COMMENT 'Survey type: NPS (likelihood to recommend, 0-10) or CSAT (satisfaction, 1-5).',
    SCORE           COMMENT 'Survey score: 0-10 for NPS, 1-5 for CSAT.',
    NPS_CATEGORY    COMMENT 'Score category. NPS: Promoter (9-10), Passive (7-8), Detractor (0-6). CSAT: Satisfied (4-5), Neutral (3), Dissatisfied (1-2).',
    VERBATIM        COMMENT 'Free-text comment left by the respondent. Searchable via BD_CUSTOMER_FEEDBACK_SEARCH.',
    RESPONSE_DATE   COMMENT 'Date the survey was answered.',
    RESPONSE_MONTH  COMMENT 'First day of the month of RESPONSE_DATE.'
)
COMMENT = 'One row per NPS or CSAT response enriched with customer and respondent context and the response month. Joined into BD_CUSTOMER_360_SV for survey analysis.'
-- @cols-end
AS
SELECT
    s.SURVEY_ID, s.CUSTOMER_ID, c.CUSTOMER_NAME, c.INDUSTRY, c.SEGMENT, c.REGION, c.CSM_NAME, c.LIFECYCLE_STAGE,
    ct.FULL_NAME AS CONTACT_NAME, ct.CONTACT_ROLE,
    s.SURVEY_TYPE, s.SCORE, s.NPS_CATEGORY, s.VERBATIM,
    s.RESPONSE_DATE, DATE_TRUNC('MONTH', s.RESPONSE_DATE)::DATE AS RESPONSE_MONTH
FROM BD_INTELLIGENCE.RAW.SURVEYS s
JOIN BD_INTELLIGENCE.RAW.CUSTOMERS c ON c.CUSTOMER_ID = s.CUSTOMER_ID
LEFT JOIN BD_INTELLIGENCE.RAW.CONTACTS ct ON ct.CONTACT_ID = s.CONTACT_ID;

-- @comments-begin (generated by scripts/build_comments.py; do not edit by hand)
COMMENT ON TABLE BD_INTELLIGENCE.ANALYTICS.CUSTOMER_ML_SCORES IS 'Latest batch scores from the Model Registry models BD_CHURN_RISK, BD_CUSTOMER_HEALTH_SCORE and BD_EXPANSION_PROPENSITY: one row per customer. Written by notebooks/07_ml_models and joined into CUSTOMER_360. Metrics are optimistic because the synthetic signals are clean.';
ALTER TABLE BD_INTELLIGENCE.ANALYTICS.CUSTOMER_ML_SCORES ALTER
    CUSTOMER_ID COMMENT 'Customer account identifier (CUST-0000 format). Joins to RAW.CUSTOMERS.',
    CHURN_RISK_SCORE COMMENT 'Predicted probability (0-1) that the customer churns within 180 days, from the BD_CHURN_RISK XGBoost model.',
    CHURN_RISK_TIER COMMENT 'Churn risk band from CHURN_RISK_SCORE: High (above 0.6), Medium (0.3-0.6) or Low (0.3 or below).',
    HEALTH_SCORE COMMENT 'Customer health score 0-100 from the BD_CUSTOMER_HEALTH_SCORE model; higher is healthier.',
    HEALTH_BAND COMMENT 'Health band from HEALTH_SCORE: Healthy (75 or more), Monitor (50-75) or At Risk (below 50).',
    EXPANSION_PROPENSITY COMMENT 'Predicted probability (0-1) that the customer wins an expansion within 180 days, from the BD_EXPANSION_PROPENSITY model.',
    EXPANSION_TIER COMMENT 'Expansion band from EXPANSION_PROPENSITY: High (above 0.6), Medium (0.3-0.6) or Low (0.3 or below).',
    TOP_RISK_DRIVERS COMMENT 'Features pushing churn risk up most for this customer (SHAP contributions), or ''No significant risk drivers''.',
    MODEL_VERSION COMMENT 'Model Registry version used for scoring (for example V1).',
    SCORED_AT COMMENT 'Timestamp the scores were produced.';
-- @comments-end
