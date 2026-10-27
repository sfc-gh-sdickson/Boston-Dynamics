-- Added BD_MAINTENANCE_TRENDS_SV semantic view for monthly maintenance trend queries
-- Co-authored with CoCo
/*=============================================================================
  Boston Dynamics Intelligence Agent
  Step 5: Semantic Views for Cortex Analyst
  
  Execution Order: 5 of 9
  Description: Creates semantic views that enable natural language querying
               via Cortex Analyst. These views provide business-friendly
               column descriptions and synonyms for the agent.
=============================================================================*/

USE DATABASE BD_INTELLIGENCE;
USE SCHEMA ANALYTICS;
USE WAREHOUSE BOSTON_DYNAMICS_WH;

-- ============================================================================
-- Semantic View: Fleet Operations
-- Enables questions about robot fleet status, deployments, and customers
-- ============================================================================
CREATE OR REPLACE SEMANTIC VIEW BD_FLEET_OPERATIONS_SV

  TABLES (
    fo AS BD_INTELLIGENCE.ANALYTICS.FLEET_OVERVIEW
      PRIMARY KEY (ROBOT_ID)
      WITH SYNONYMS ('fleet overview', 'robot fleet', 'fleet')
      COMMENT = 'Fleet overview including robots, deployments, customers, components, and overall fleet health'
  )

  DIMENSIONS (
    fo.robot_id AS ROBOT_ID
      COMMENT = 'Unique identifier for each robot in the fleet',
    fo.robot_name AS ROBOT_NAME
      WITH SYNONYMS = ('robot', 'bot', 'unit')
      COMMENT = 'Human-readable name of the robot including model prefix',
    fo.robot_model AS ROBOT_MODEL
      WITH SYNONYMS = ('model', 'type', 'robot type', 'platform')
      COMMENT = 'Robot model: Atlas (humanoid), Spot (quadruped), or Stretch (warehouse)',
    fo.serial_number AS SERIAL_NUMBER
      COMMENT = 'Manufacturing serial number for the robot',
    fo.robot_status AS ROBOT_STATUS
      WITH SYNONYMS = ('status', 'state', 'condition', 'operational status')
      COMMENT = 'Current robot status: Active, Idle, Maintenance, or Decommissioned',
    fo.firmware_version AS FIRMWARE_VERSION
      WITH SYNONYMS = ('firmware', 'software version', 'version')
      COMMENT = 'Currently installed firmware version',
    fo.manufacture_date AS MANUFACTURE_DATE
      WITH SYNONYMS = ('build date', 'production date', 'manufactured')
      COMMENT = 'Date the robot was manufactured',
    fo.site_name AS SITE_NAME
      WITH SYNONYMS = ('site', 'location', 'deployment site', 'facility')
      COMMENT = 'Name of the deployment site where the robot operates',
    fo.site_type AS SITE_TYPE
      WITH SYNONYMS = ('facility type', 'location type')
      COMMENT = 'Type of deployment site: Manufacturing Floor, Warehouse, Outdoor, etc.',
    fo.primary_use_case AS PRIMARY_USE_CASE
      WITH SYNONYMS = ('use case', 'application', 'purpose', 'task')
      COMMENT = 'Primary operational use case at the deployment site',
    fo.deployment_environment AS DEPLOYMENT_ENVIRONMENT
      WITH SYNONYMS = ('environment', 'operating environment')
      COMMENT = 'Operating environment: Indoor, Outdoor, Mixed, or Hazardous',
    fo.customer_name AS CUSTOMER_NAME
      WITH SYNONYMS = ('customer', 'client', 'account', 'company')
      COMMENT = 'Name of the customer organization',
    fo.customer_industry AS CUSTOMER_INDUSTRY
      WITH SYNONYMS = ('industry', 'sector', 'vertical')
      COMMENT = 'Industry vertical of the customer',
    fo.customer_region AS CUSTOMER_REGION
      WITH SYNONYMS = ('region', 'geography', 'area')
      COMMENT = 'Geographic region of the customer',
    fo.support_tier AS SUPPORT_TIER
      WITH SYNONYMS = ('support level', 'service tier', 'SLA tier')
      COMMENT = 'Customer support tier: Platinum, Gold, Silver, or Bronze'
  )

  METRICS (
    fo.age_days AS SUM(AGE_DAYS)
      WITH SYNONYMS = ('age', 'days old', 'robot age')
      COMMENT = 'Number of days since the robot was manufactured',
    fo.total_components AS SUM(TOTAL_COMPONENTS)
      WITH SYNONYMS = ('component count', 'parts count', 'number of components')
      COMMENT = 'Total number of components installed on the robot',
    fo.healthy_components AS SUM(HEALTHY_COMPONENTS)
      WITH SYNONYMS = ('working components', 'operational components', 'good components')
      COMMENT = 'Number of components in Operational status',
    fo.degraded_components AS SUM(DEGRADED_COMPONENTS)
      WITH SYNONYMS = ('worn components', 'aging components')
      COMMENT = 'Number of components in Degraded status',
    fo.critical_components AS SUM(CRITICAL_COMPONENTS)
      WITH SYNONYMS = ('failing components', 'bad components', 'components needing replacement')
      COMMENT = 'Number of components that are Failed or Need Replacement'
  )

  COMMENT = 'Semantic view for Boston Dynamics fleet operations including robots, deployments, customers, components, and overall fleet health';

-- ============================================================================
-- Semantic View: Telemetry Analytics
-- Enables questions about robot telemetry, sensor data, and performance
-- ============================================================================
CREATE OR REPLACE SEMANTIC VIEW BD_TELEMETRY_ANALYTICS_SV

  TABLES (
    ts AS BD_INTELLIGENCE.ANALYTICS.TELEMETRY_DAILY_SUMMARY
      PRIMARY KEY (ROBOT_ID, TELEMETRY_DATE)
      WITH SYNONYMS ('telemetry', 'sensor data', 'robot telemetry')
      COMMENT = 'Daily telemetry summary including battery, temperature, vibration, speed, and error metrics'
  )

  DIMENSIONS (
    ts.robot_id AS ROBOT_ID
      COMMENT = 'Unique identifier for the robot',
    ts.robot_name AS ROBOT_NAME
      WITH SYNONYMS = ('robot', 'bot', 'unit')
      COMMENT = 'Name of the robot',
    ts.robot_model AS ROBOT_MODEL
      WITH SYNONYMS = ('model', 'type', 'platform')
      COMMENT = 'Robot model: Atlas, Spot, or Stretch',
    ts.telemetry_date AS TELEMETRY_DATE
      WITH SYNONYMS = ('date', 'day', 'reading date')
      COMMENT = 'Date of the telemetry readings'
  )

  METRICS (
    ts.reading_count AS SUM(READING_COUNT)
      WITH SYNONYMS = ('readings', 'data points', 'samples')
      COMMENT = 'Number of telemetry readings recorded on this date',
    ts.avg_battery_level AS AVG(AVG_BATTERY_LEVEL)
      WITH SYNONYMS = ('battery', 'charge level', 'power level', 'battery percentage')
      COMMENT = 'Average battery level percentage for the day',
    ts.min_battery_level AS MIN(MIN_BATTERY_LEVEL)
      WITH SYNONYMS = ('lowest battery', 'minimum charge')
      COMMENT = 'Minimum battery level recorded during the day',
    ts.avg_cpu_temp_c AS AVG(AVG_CPU_TEMP_C)
      WITH SYNONYMS = ('cpu temperature', 'processor temperature', 'cpu heat')
      COMMENT = 'Average CPU temperature in Celsius',
    ts.max_cpu_temp_c AS MAX(MAX_CPU_TEMP_C)
      WITH SYNONYMS = ('peak cpu temp', 'highest cpu temperature')
      COMMENT = 'Maximum CPU temperature in Celsius',
    ts.avg_motor_temp_c AS AVG(AVG_MOTOR_TEMP_C)
      WITH SYNONYMS = ('motor temperature', 'motor heat', 'actuator temperature')
      COMMENT = 'Average motor temperature in Celsius',
    ts.max_motor_temp_c AS MAX(MAX_MOTOR_TEMP_C)
      WITH SYNONYMS = ('peak motor temp', 'highest motor temperature')
      COMMENT = 'Maximum motor temperature in Celsius',
    ts.avg_vibration AS AVG(AVG_VIBRATION)
      WITH SYNONYMS = ('vibration', 'vibration level', 'shake')
      COMMENT = 'Average vibration level in mm/s',
    ts.max_vibration AS MAX(MAX_VIBRATION)
      WITH SYNONYMS = ('peak vibration', 'maximum vibration')
      COMMENT = 'Maximum vibration level in mm/s',
    ts.avg_joint_load AS AVG(AVG_JOINT_LOAD)
      WITH SYNONYMS = ('joint load', 'load percentage', 'joint stress')
      COMMENT = 'Average joint load as percentage of maximum capacity',
    ts.max_joint_load AS MAX(MAX_JOINT_LOAD)
      WITH SYNONYMS = ('peak load', 'maximum joint load')
      COMMENT = 'Maximum joint load percentage recorded',
    ts.avg_speed_m_s AS AVG(AVG_SPEED_M_S)
      WITH SYNONYMS = ('speed', 'velocity', 'movement speed')
      COMMENT = 'Average movement speed in meters per second',
    ts.max_speed_m_s AS MAX(MAX_SPEED_M_S)
      WITH SYNONYMS = ('top speed', 'maximum speed', 'peak speed')
      COMMENT = 'Maximum speed recorded in meters per second',
    ts.error_count AS SUM(ERROR_COUNT)
      WITH SYNONYMS = ('errors', 'faults', 'error occurrences')
      COMMENT = 'Number of error codes recorded during the day',
    ts.distinct_modes AS SUM(DISTINCT_MODES)
      WITH SYNONYMS = ('operational modes', 'modes used')
      COMMENT = 'Number of distinct operational modes used during the day'
  )

  COMMENT = 'Semantic view for Boston Dynamics robot telemetry data including battery, temperature, vibration, speed, and error metrics';

-- ============================================================================
-- Semantic View: Maintenance Intelligence
-- Enables questions about maintenance history, costs, and scheduling
-- ============================================================================
CREATE OR REPLACE SEMANTIC VIEW BD_MAINTENANCE_INTELLIGENCE_SV

  TABLES (
    ma AS BD_INTELLIGENCE.ANALYTICS.MAINTENANCE_ANALYSIS
      PRIMARY KEY (ROBOT_ID, MAINTENANCE_TYPE)
      WITH SYNONYMS ('maintenance', 'service records', 'maintenance history')
      COMMENT = 'Maintenance records including costs, frequency, duration, and scheduling across the robot fleet'
  )

  DIMENSIONS (
    ma.robot_id AS ROBOT_ID
      COMMENT = 'Robot identifier',
    ma.robot_name AS ROBOT_NAME
      WITH SYNONYMS = ('robot', 'bot', 'unit')
      COMMENT = 'Name of the robot',
    ma.robot_model AS ROBOT_MODEL
      WITH SYNONYMS = ('model', 'type', 'platform')
      COMMENT = 'Robot model: Atlas, Spot, or Stretch',
    ma.site_name AS SITE_NAME
      WITH SYNONYMS = ('site', 'location', 'facility')
      COMMENT = 'Deployment site name',
    ma.customer_name AS CUSTOMER_NAME
      WITH SYNONYMS = ('customer', 'client', 'account')
      COMMENT = 'Customer organization name',
    ma.maintenance_type AS MAINTENANCE_TYPE
      WITH SYNONYMS = ('type', 'service type', 'maintenance category')
      COMMENT = 'Type of maintenance: Preventive, Corrective, Predictive, Firmware Update, or Calibration',
    ma.first_maintenance_date AS FIRST_MAINTENANCE_DATE
      WITH SYNONYMS = ('first service', 'earliest maintenance')
      COMMENT = 'Date of the first maintenance event',
    ma.last_maintenance_date AS LAST_MAINTENANCE_DATE
      WITH SYNONYMS = ('last service', 'most recent maintenance', 'latest maintenance')
      COMMENT = 'Date of the most recent maintenance event'
  )

  METRICS (
    ma.maintenance_count AS SUM(MAINTENANCE_COUNT)
      WITH SYNONYMS = ('count', 'frequency', 'number of events', 'how many')
      COMMENT = 'Total number of maintenance events',
    ma.total_cost_usd AS SUM(TOTAL_COST_USD)
      WITH SYNONYMS = ('total cost', 'cost', 'expense', 'spending', 'money spent')
      COMMENT = 'Total maintenance cost in US dollars',
    ma.avg_cost_usd AS AVG(AVG_COST_USD)
      WITH SYNONYMS = ('average cost', 'cost per event')
      COMMENT = 'Average cost per maintenance event in US dollars',
    ma.avg_duration_minutes AS AVG(AVG_DURATION_MINUTES)
      WITH SYNONYMS = ('average duration', 'time per event', 'average time')
      COMMENT = 'Average duration of maintenance events in minutes',
    ma.total_duration_minutes AS SUM(TOTAL_DURATION_MINUTES)
      WITH SYNONYMS = ('total time', 'total duration', 'hours spent')
      COMMENT = 'Total time spent on maintenance in minutes',
    ma.parts_replacement_count AS SUM(PARTS_REPLACEMENT_COUNT)
      WITH SYNONYMS = ('parts replaced', 'replacement count', 'components swapped')
      COMMENT = 'Number of maintenance events that involved replacing parts'
  )

  COMMENT = 'Semantic view for Boston Dynamics maintenance records including costs, frequency, duration, and scheduling across the robot fleet';

-- ============================================================================
-- Semantic View: Maintenance Monthly Trends
-- Enables questions about maintenance cost trends over time
-- ============================================================================
CREATE OR REPLACE SEMANTIC VIEW BD_MAINTENANCE_TRENDS_SV

  TABLES (
    mt AS BD_INTELLIGENCE.ANALYTICS.MAINTENANCE_MONTHLY_TREND
      PRIMARY KEY (MAINTENANCE_MONTH, ROBOT_MODEL, MAINTENANCE_TYPE, TECHNICIAN, SITE_NAME, CUSTOMER_NAME)
      WITH SYNONYMS ('maintenance trends', 'maintenance over time', 'monthly maintenance')
      COMMENT = 'Monthly maintenance trends including costs, event counts, and duration over time by robot model, type, site, and technician'
  )

  DIMENSIONS (
    mt.maintenance_month AS MAINTENANCE_MONTH
      WITH SYNONYMS = ('month', 'date', 'period', 'time period')
      COMMENT = 'Month of the maintenance events (first day of month)',
    mt.robot_model AS ROBOT_MODEL
      WITH SYNONYMS = ('model', 'type', 'platform')
      COMMENT = 'Robot model: Atlas, Spot, or Stretch',
    mt.maintenance_type AS MAINTENANCE_TYPE
      WITH SYNONYMS = ('type', 'service type', 'maintenance category')
      COMMENT = 'Type of maintenance: Preventive, Corrective, Predictive, Firmware Update, or Calibration',
    mt.site_name AS SITE_NAME
      WITH SYNONYMS = ('site', 'location', 'facility')
      COMMENT = 'Deployment site name',
    mt.customer_name AS CUSTOMER_NAME
      WITH SYNONYMS = ('customer', 'client', 'account')
      COMMENT = 'Customer organization name',
    mt.technician AS TECHNICIAN
      WITH SYNONYMS = ('tech', 'engineer', 'performed by', 'maintenance technician', 'service engineer')
      COMMENT = 'Name of the technician who performed the maintenance'
  )

  METRICS (
    mt.event_count AS SUM(EVENT_COUNT)
      WITH SYNONYMS = ('count', 'number of events', 'how many', 'frequency')
      COMMENT = 'Number of maintenance events in the month',
    mt.total_cost_usd AS SUM(TOTAL_COST_USD)
      WITH SYNONYMS = ('total cost', 'cost', 'expense', 'spending', 'money spent', 'maintenance cost')
      COMMENT = 'Total maintenance cost in US dollars for the month',
    mt.avg_cost_usd AS AVG(AVG_COST_USD)
      WITH SYNONYMS = ('average cost', 'cost per event')
      COMMENT = 'Average cost per maintenance event in US dollars',
    mt.total_duration_minutes AS SUM(TOTAL_DURATION_MINUTES)
      WITH SYNONYMS = ('total time', 'total duration', 'hours spent')
      COMMENT = 'Total time spent on maintenance in minutes for the month',
    mt.avg_duration_minutes AS AVG(AVG_DURATION_MINUTES)
      WITH SYNONYMS = ('average duration', 'time per event', 'average time')
      COMMENT = 'Average duration of maintenance events in minutes',
    mt.parts_replacement_count AS SUM(PARTS_REPLACEMENT_COUNT)
      WITH SYNONYMS = ('parts replaced', 'replacement count', 'components swapped')
      COMMENT = 'Number of events involving parts replacement in the month'
  )

  COMMENT = 'Semantic view for Boston Dynamics monthly maintenance trends enabling time-series analysis of costs, frequency, and duration';

-- ============================================================================
-- Semantic View: Incident Analysis
-- Enables questions about incidents, downtime, and safety events
-- ============================================================================
CREATE OR REPLACE SEMANTIC VIEW BD_INCIDENT_ANALYSIS_SV

  TABLES (
    id AS BD_INTELLIGENCE.ANALYTICS.INCIDENT_DASHBOARD
      PRIMARY KEY (ROBOT_ID, INCIDENT_TYPE, SEVERITY)
      WITH SYNONYMS ('incidents', 'safety events', 'incident reports')
      COMMENT = 'Incident tracking including incident types, severity, downtime, and resolution status'
  )

  DIMENSIONS (
    id.robot_id AS ROBOT_ID
      COMMENT = 'Robot identifier',
    id.robot_name AS ROBOT_NAME
      WITH SYNONYMS = ('robot', 'bot', 'unit')
      COMMENT = 'Name of the robot',
    id.robot_model AS ROBOT_MODEL
      WITH SYNONYMS = ('model', 'type', 'platform')
      COMMENT = 'Robot model: Atlas, Spot, or Stretch',
    id.site_name AS SITE_NAME
      WITH SYNONYMS = ('site', 'location', 'facility')
      COMMENT = 'Deployment site where incidents occurred',
    id.customer_name AS CUSTOMER_NAME
      WITH SYNONYMS = ('customer', 'client', 'account')
      COMMENT = 'Customer organization name',
    id.customer_industry AS CUSTOMER_INDUSTRY
      WITH SYNONYMS = ('industry', 'sector')
      COMMENT = 'Industry vertical of the customer',
    id.incident_type AS INCIDENT_TYPE
      WITH SYNONYMS = ('type', 'incident category', 'failure type', 'issue type')
      COMMENT = 'Category of incident: Hardware Failure, Software Error, Communication Loss, etc.',
    id.severity AS SEVERITY
      WITH SYNONYMS = ('priority', 'criticality', 'impact level')
      COMMENT = 'Incident severity: Critical, High, Medium, or Low',
    id.first_incident_date AS FIRST_INCIDENT_DATE
      WITH SYNONYMS = ('first incident', 'earliest incident')
      COMMENT = 'Date of the first incident',
    id.last_incident_date AS LAST_INCIDENT_DATE
      WITH SYNONYMS = ('last incident', 'most recent incident', 'latest incident')
      COMMENT = 'Date of the most recent incident'
  )

  METRICS (
    id.incident_count AS SUM(INCIDENT_COUNT)
      WITH SYNONYMS = ('count', 'number of incidents', 'how many incidents', 'occurrences')
      COMMENT = 'Total number of incidents',
    id.total_downtime_minutes AS SUM(TOTAL_DOWNTIME_MINUTES)
      WITH SYNONYMS = ('downtime', 'total downtime', 'outage time', 'unavailable time')
      COMMENT = 'Total downtime caused by incidents in minutes',
    id.avg_downtime_minutes AS AVG(AVG_DOWNTIME_MINUTES)
      WITH SYNONYMS = ('average downtime', 'mean downtime')
      COMMENT = 'Average downtime per incident in minutes',
    id.resolved_count AS SUM(RESOLVED_COUNT)
      WITH SYNONYMS = ('resolved', 'fixed', 'closed')
      COMMENT = 'Number of incidents that have been resolved',
    id.unresolved_count AS SUM(UNRESOLVED_COUNT)
      WITH SYNONYMS = ('unresolved', 'open', 'pending', 'outstanding')
      COMMENT = 'Number of incidents still open or unresolved'
  )

  COMMENT = 'Semantic view for Boston Dynamics incident tracking including incident types, severity, downtime, and resolution status';

-- ============================================================================
-- CUSTOMER 360 SEMANTIC VIEWS
-- ============================================================================

-- ============================================================================
-- Semantic View: Customer 360
-- One row per customer plus NPS/CSAT survey responses
-- ============================================================================
CREATE OR REPLACE SEMANTIC VIEW BD_CUSTOMER_360_SV

  TABLES (
    c360 AS BD_INTELLIGENCE.ANALYTICS.CUSTOMER_360
      PRIMARY KEY (CUSTOMER_ID)
      WITH SYNONYMS ('customer 360', 'customers', 'accounts', 'account health', 'customer profile')
      COMMENT = 'One row per customer combining ARR, fleet, adoption, support, NPS, billing, pipeline, interactions and ML scores (churn risk, health score, expansion propensity)',
    srv AS BD_INTELLIGENCE.ANALYTICS.CUSTOMER_SURVEY_RESULTS
      PRIMARY KEY (SURVEY_ID)
      WITH SYNONYMS ('surveys', 'nps', 'csat', 'customer feedback', 'survey responses')
      COMMENT = 'Individual NPS (0-10) and CSAT (1-5) survey responses with verbatim comments'
  )

  RELATIONSHIPS (
    survey_to_customer AS srv (CUSTOMER_ID) REFERENCES c360
  )

  FACTS (
    c360.arr_at_risk AS IFF(CHURN_RISK_TIER = 'High', CURRENT_ARR_USD, 0)
      COMMENT = 'Current ARR if the customer is High churn risk, else 0',
    srv.is_nps_response AS IFF(SURVEY_TYPE = 'NPS', 1, 0),
    srv.is_nps_promoter AS IFF(SURVEY_TYPE = 'NPS' AND SCORE >= 9, 1, 0),
    srv.is_nps_detractor AS IFF(SURVEY_TYPE = 'NPS' AND SCORE <= 6, 1, 0)
  )

  DIMENSIONS (
    c360.customer_id AS CUSTOMER_ID
      COMMENT = 'Unique customer identifier',
    c360.customer_name AS CUSTOMER_NAME
      WITH SYNONYMS = ('customer', 'account', 'client', 'company')
      COMMENT = 'Customer organization name',
    c360.industry AS INDUSTRY
      WITH SYNONYMS = ('vertical', 'sector')
      COMMENT = 'Industry vertical',
    c360.segment AS SEGMENT
      WITH SYNONYMS = ('customer segment', 'tier', 'account segment')
      COMMENT = 'Customer segment: Strategic, Enterprise, or Commercial',
    c360.company_size AS COMPANY_SIZE
      COMMENT = 'Company size band: Enterprise, Large, Mid-Market',
    c360.region AS REGION
      WITH SYNONYMS = ('geography', 'geo')
      COMMENT = 'Geographic region',
    c360.country AS COUNTRY
      COMMENT = 'Headquarters country',
    c360.support_tier AS SUPPORT_TIER
      WITH SYNONYMS = ('support level', 'SLA tier')
      COMMENT = 'Support tier: Platinum, Gold, Silver, Bronze',
    c360.account_manager AS ACCOUNT_MANAGER
      WITH SYNONYMS = ('AE', 'account executive', 'sales rep', 'owner')
      COMMENT = 'Account manager responsible for the customer',
    c360.csm_name AS CSM_NAME
      WITH SYNONYMS = ('CSM', 'customer success manager')
      COMMENT = 'Assigned customer success manager',
    c360.lifecycle_stage AS LIFECYCLE_STAGE
      WITH SYNONYMS = ('stage', 'customer stage', 'lifecycle')
      COMMENT = 'Lifecycle stage: Onboarding, Adopting, Mature, Renewal Due, or Churned',
    c360.customer_since AS CUSTOMER_SINCE
      WITH SYNONYMS = ('start date', 'first contract date')
      COMMENT = 'Date of the first contract',
    c360.contract_end_date AS CONTRACT_END_DATE
      WITH SYNONYMS = ('renewal date', 'contract expiry', 'expiration date')
      COMMENT = 'End date of the current contract (renewal date)',
    c360.primary_contract_type AS PRIMARY_CONTRACT_TYPE
      WITH SYNONYMS = ('contract type', 'commercial model')
      COMMENT = 'Contract type: RaaS Subscription, Lease, or Purchase + Support',
    c360.primary_product_line AS PRIMARY_PRODUCT_LINE
      WITH SYNONYMS = ('product', 'main product', 'robot line')
      COMMENT = 'Dominant robot product line: Atlas, Spot, or Stretch',
    c360.latest_nps_category AS LATEST_NPS_CATEGORY
      WITH SYNONYMS = ('nps category', 'promoter or detractor')
      COMMENT = 'Most recent NPS category: Promoter, Passive, or Detractor',
    c360.renewal_stage AS RENEWAL_STAGE
      COMMENT = 'Stage of the open renewal opportunity, if any',
    c360.last_interaction_type AS LAST_INTERACTION_TYPE
      COMMENT = 'Type of the most recent customer interaction',
    c360.churn_risk_tier AS CHURN_RISK_TIER
      WITH SYNONYMS = ('churn risk', 'risk tier', 'at risk')
      COMMENT = 'ML churn risk tier: High, Medium, or Low',
    c360.health_band AS HEALTH_BAND
      WITH SYNONYMS = ('health', 'account health', 'health status')
      COMMENT = 'ML health score band: Healthy (75-100), Monitor (50-74), At Risk (<50)',
    c360.expansion_tier AS EXPANSION_TIER
      WITH SYNONYMS = ('expansion potential', 'upsell potential')
      COMMENT = 'ML expansion propensity tier: High, Medium, or Low',
    c360.top_risk_drivers AS TOP_RISK_DRIVERS
      WITH SYNONYMS = ('risk drivers', 'why at risk', 'churn reasons')
      COMMENT = 'Top factors driving churn risk for the customer',
    srv.survey_type AS SURVEY_TYPE
      COMMENT = 'Survey type: NPS or CSAT',
    srv.nps_category AS NPS_CATEGORY
      WITH SYNONYMS = ('response category', 'promoter', 'detractor')
      COMMENT = 'Promoter/Passive/Detractor for NPS; Satisfied/Neutral/Dissatisfied for CSAT',
    srv.verbatim AS VERBATIM
      WITH SYNONYMS = ('comment', 'feedback', 'verbatim comment')
      COMMENT = 'Free-text survey comment',
    srv.contact_role AS CONTACT_ROLE
      COMMENT = 'Role of the survey respondent',
    srv.response_date AS RESPONSE_DATE
      WITH SYNONYMS = ('survey date', 'date')
      COMMENT = 'Date of the survey response',
    srv.response_month AS RESPONSE_MONTH
      WITH SYNONYMS = ('survey month', 'month')
      COMMENT = 'Month of the survey response'
  )

  METRICS (
    c360.customer_count AS COUNT(CUSTOMER_ID)
      WITH SYNONYMS = ('number of customers', 'how many customers', 'account count')
      COMMENT = 'Number of customers',
    c360.total_arr_usd AS SUM(CURRENT_ARR_USD)
      WITH SYNONYMS = ('ARR', 'annual recurring revenue', 'recurring revenue', 'revenue')
      COMMENT = 'Current annual recurring revenue from active contracts in USD',
    c360.churned_arr_usd AS SUM(CHURNED_ARR_USD)
      WITH SYNONYMS = ('lost ARR', 'churned revenue')
      COMMENT = 'ARR lost from churned contracts in USD',
    c360.lifetime_contract_value_usd AS SUM(LIFETIME_CONTRACT_VALUE_USD)
      WITH SYNONYMS = ('lifetime value', 'LTV', 'total contract value')
      COMMENT = 'Total value of all contracts signed by the customer in USD',
    c360.total_robots AS SUM(TOTAL_ROBOTS)
      WITH SYNONYMS = ('fleet size', 'robots', 'robot count')
      COMMENT = 'Total robots deployed at the customer',
    c360.site_count AS SUM(SITE_COUNT)
      WITH SYNONYMS = ('sites', 'deployments', 'locations')
      COMMENT = 'Number of deployment sites',
    c360.days_to_renewal AS MIN(DAYS_TO_RENEWAL)
      WITH SYNONYMS = ('days until renewal', 'renewal in days')
      COMMENT = 'Days until the current contract ends',
    c360.avg_churn_risk AS AVG(CHURN_RISK_SCORE)
      WITH SYNONYMS = ('churn probability', 'churn risk score', 'likelihood to churn')
      COMMENT = 'ML churn risk probability (0-1)',
    c360.avg_health_score AS AVG(HEALTH_SCORE)
      WITH SYNONYMS = ('health score', 'customer health')
      COMMENT = 'ML customer health score (0-100)',
    c360.avg_expansion_propensity AS AVG(EXPANSION_PROPENSITY)
      WITH SYNONYMS = ('expansion score', 'upsell likelihood', 'expansion probability')
      COMMENT = 'ML expansion propensity probability (0-1)',
    c360.arr_at_risk_usd AS SUM(c360.arr_at_risk)
      WITH SYNONYMS = ('ARR at risk', 'revenue at risk')
      COMMENT = 'ARR from customers with High churn risk',
    c360.avg_nps_6m AS AVG(AVG_NPS_6M)
      WITH SYNONYMS = ('NPS', 'net promoter score', 'recent NPS')
      COMMENT = 'Average NPS score over the last 6 months (0-10 scale)',
    c360.avg_nps_trend AS AVG(NPS_TREND)
      WITH SYNONYMS = ('NPS change', 'NPS trend')
      COMMENT = 'Change in average NPS: last 6 months minus prior 6 months',
    c360.avg_utilization_pct AS AVG(UTILIZATION_PCT_30D)
      WITH SYNONYMS = ('utilization', 'adoption', 'robot utilization')
      COMMENT = 'Average daily active robots as a percent of fleet, last 30 days',
    c360.avg_usage_trend_pct AS AVG(USAGE_TREND_PCT)
      WITH SYNONYMS = ('usage trend', 'usage change', 'adoption trend')
      COMMENT = 'Percent change in active robots: last 30 days vs prior 90 days',
    c360.avg_autonomy_pct AS AVG(AUTONOMY_PCT_30D)
      WITH SYNONYMS = ('autonomy', 'autonomous percentage')
      COMMENT = 'Average percent of operating time spent autonomously, last 30 days',
    c360.tickets_90d AS SUM(TICKETS_90D)
      WITH SYNONYMS = ('support tickets', 'cases', 'ticket volume')
      COMMENT = 'Support tickets opened in the last 90 days',
    c360.open_tickets AS SUM(OPEN_TICKETS)
      WITH SYNONYMS = ('open cases', 'unresolved tickets')
      COMMENT = 'Currently open support tickets',
    c360.avg_sla_met_pct AS AVG(SLA_MET_PCT_90D)
      WITH SYNONYMS = ('SLA attainment', 'SLA met')
      COMMENT = 'Percent of closed tickets meeting SLA, last 90 days',
    c360.incidents_90d AS SUM(INCIDENTS_90D)
      WITH SYNONYMS = ('incidents', 'robot incidents')
      COMMENT = 'Robot incidents in the last 90 days',
    c360.critical_incidents_90d AS SUM(CRITICAL_INCIDENTS_90D)
      WITH SYNONYMS = ('critical incidents', 'severe incidents')
      COMMENT = 'Critical-severity incidents in the last 90 days',
    c360.avg_late_payment_pct AS AVG(LATE_PAYMENT_PCT_12M)
      WITH SYNONYMS = ('late payments', 'payment delinquency')
      COMMENT = 'Percent of invoices paid late or overdue, last 12 months',
    c360.overdue_amount_usd AS SUM(OVERDUE_AMOUNT_USD)
      WITH SYNONYMS = ('overdue', 'past due', 'outstanding AR', 'receivables overdue')
      COMMENT = 'Total overdue invoice amount in USD',
    c360.open_pipeline_usd AS SUM(OPEN_PIPELINE_USD)
      WITH SYNONYMS = ('pipeline', 'open pipeline')
      COMMENT = 'Open opportunity amount in USD (all types)',
    c360.open_expansion_pipeline_usd AS SUM(OPEN_EXPANSION_PIPELINE_USD)
      WITH SYNONYMS = ('expansion pipeline', 'upsell pipeline')
      COMMENT = 'Open non-renewal opportunity amount in USD',
    c360.expansion_won_12m_usd AS SUM(EXPANSION_WON_12M_USD)
      WITH SYNONYMS = ('expansion bookings', 'upsell won')
      COMMENT = 'Won expansion/upsell/new site/services amount in the last 12 months',
    c360.avg_negative_sentiment_pct AS AVG(NEGATIVE_SENTIMENT_PCT_90D)
      WITH SYNONYMS = ('negative sentiment', 'sentiment')
      COMMENT = 'Percent of interactions with negative sentiment, last 90 days',
    c360.days_since_last_interaction AS MIN(DAYS_SINCE_LAST_INTERACTION)
      WITH SYNONYMS = ('last touch', 'days since contact')
      COMMENT = 'Days since the most recent customer interaction',
    srv.response_count AS COUNT(SURVEY_ID)
      WITH SYNONYMS = ('survey responses', 'number of responses')
      COMMENT = 'Number of survey responses',
    srv.avg_score AS AVG(SCORE)
      WITH SYNONYMS = ('average score', 'survey score', 'average NPS', 'average CSAT')
      COMMENT = 'Average survey score; filter SURVEY_TYPE to NPS (0-10) or CSAT (1-5)',
    srv.nps AS 100.0 * (SUM(srv.is_nps_promoter) - SUM(srv.is_nps_detractor)) / NULLIF(SUM(srv.is_nps_response), 0)
      WITH SYNONYMS = ('net promoter score', 'NPS score')
      COMMENT = 'Net Promoter Score (-100 to 100): percent promoters minus percent detractors'
  )

  COMMENT = 'Customer 360 semantic view: account profile, ARR, adoption, support, sentiment, billing, pipeline, ML churn risk, health score and expansion propensity, plus NPS/CSAT survey responses';

-- ============================================================================
-- Semantic View: Revenue
-- Grain: CUSTOMER_ID, REVENUE_MONTH
-- ============================================================================
CREATE OR REPLACE SEMANTIC VIEW BD_REVENUE_SV

  TABLES (
    rev AS BD_INTELLIGENCE.ANALYTICS.CUSTOMER_REVENUE_MONTHLY
      PRIMARY KEY (CUSTOMER_ID, REVENUE_MONTH)
      WITH SYNONYMS ('revenue', 'billing', 'invoices', 'collections')
      COMMENT = 'Monthly invoiced, collected, late and overdue amounts per customer'
  )

  DIMENSIONS (
    rev.customer_id AS CUSTOMER_ID
      COMMENT = 'Customer identifier',
    rev.revenue_month AS REVENUE_MONTH
      WITH SYNONYMS = ('month', 'billing month', 'invoice month')
      COMMENT = 'Month of invoice (first day of month)',
    rev.customer_name AS CUSTOMER_NAME
      WITH SYNONYMS = ('customer', 'account', 'client')
      COMMENT = 'Customer name',
    rev.industry AS INDUSTRY
      WITH SYNONYMS = ('vertical', 'sector')
      COMMENT = 'Industry vertical',
    rev.segment AS SEGMENT
      COMMENT = 'Customer segment: Strategic, Enterprise, Commercial',
    rev.region AS REGION
      COMMENT = 'Geographic region',
    rev.account_manager AS ACCOUNT_MANAGER
      WITH SYNONYMS = ('AE', 'sales rep')
      COMMENT = 'Account manager',
    rev.lifecycle_stage AS LIFECYCLE_STAGE
      COMMENT = 'Customer lifecycle stage'
  )

  METRICS (
    rev.invoiced_usd AS SUM(INVOICED_USD)
      WITH SYNONYMS = ('billings', 'invoiced', 'billed revenue', 'revenue')
      COMMENT = 'Total invoiced amount in USD',
    rev.collected_usd AS SUM(COLLECTED_USD)
      WITH SYNONYMS = ('collections', 'cash collected', 'paid')
      COMMENT = 'Amount paid (on time or late) in USD',
    rev.paid_late_usd AS SUM(PAID_LATE_USD)
      WITH SYNONYMS = ('late payments')
      COMMENT = 'Amount paid after the due date in USD',
    rev.overdue_usd AS SUM(OVERDUE_USD)
      WITH SYNONYMS = ('overdue', 'past due', 'delinquent')
      COMMENT = 'Unpaid amount past due date in USD',
    rev.open_usd AS SUM(OPEN_USD)
      WITH SYNONYMS = ('outstanding', 'not yet due')
      COMMENT = 'Unpaid amount not yet due in USD',
    rev.invoice_count AS SUM(INVOICE_COUNT)
      WITH SYNONYMS = ('number of invoices')
      COMMENT = 'Number of invoices',
    rev.late_invoice_count AS SUM(LATE_INVOICE_COUNT)
      WITH SYNONYMS = ('late invoices')
      COMMENT = 'Invoices paid late or overdue',
    rev.avg_days_late AS AVG(AVG_DAYS_LATE)
      WITH SYNONYMS = ('days late', 'DSO')
      COMMENT = 'Average days late per invoice'
  )

  COMMENT = 'Semantic view for Boston Dynamics customer billing and collections by month';

-- ============================================================================
-- Semantic View: Customer Support
-- Grain: TICKET_ID
-- ============================================================================
CREATE OR REPLACE SEMANTIC VIEW BD_SUPPORT_SV

  TABLES (
    tk AS BD_INTELLIGENCE.ANALYTICS.SUPPORT_TICKET_ANALYSIS
      PRIMARY KEY (TICKET_ID)
      WITH SYNONYMS ('support tickets', 'cases', 'tickets', 'customer support')
      COMMENT = 'Customer support tickets with priority, SLA, resolution time and CSAT'
  )

  FACTS (
    tk.is_open AS IFF(STATUS = 'Open', 1, 0),
    tk.is_closed AS IFF(STATUS = 'Closed', 1, 0),
    tk.is_sla_met AS IFF(SLA_MET, 1, 0)
  )

  DIMENSIONS (
    tk.ticket_id AS TICKET_ID
      COMMENT = 'Ticket identifier',
    tk.customer_name AS CUSTOMER_NAME
      WITH SYNONYMS = ('customer', 'account', 'client')
      COMMENT = 'Customer name',
    tk.industry AS INDUSTRY
      COMMENT = 'Industry vertical',
    tk.segment AS SEGMENT
      COMMENT = 'Customer segment',
    tk.region AS REGION
      COMMENT = 'Geographic region',
    tk.support_tier AS SUPPORT_TIER
      WITH SYNONYMS = ('support level')
      COMMENT = 'Customer support tier',
    tk.csm_name AS CSM_NAME
      WITH SYNONYMS = ('CSM')
      COMMENT = 'Customer success manager',
    tk.robot_id AS ROBOT_ID
      COMMENT = 'Robot referenced by the ticket, if any',
    tk.robot_model AS ROBOT_MODEL
      WITH SYNONYMS = ('model', 'product')
      COMMENT = 'Robot model referenced by the ticket',
    tk.category AS CATEGORY
      WITH SYNONYMS = ('ticket category', 'issue type', 'topic')
      COMMENT = 'Ticket category: Hardware, Software, Navigation, Battery, Connectivity, Integration, Billing, Training',
    tk.priority AS PRIORITY
      WITH SYNONYMS = ('severity', 'urgency')
      COMMENT = 'Ticket priority: Critical, High, Medium, Low',
    tk.channel AS CHANNEL
      COMMENT = 'Channel: Portal, Email, Phone, Field Engineer',
    tk.status AS STATUS
      WITH SYNONYMS = ('ticket status', 'open or closed')
      COMMENT = 'Open or Closed',
    tk.subject AS SUBJECT
      COMMENT = 'Ticket subject line',
    tk.assigned_to AS ASSIGNED_TO
      WITH SYNONYMS = ('support engineer', 'agent', 'assignee')
      COMMENT = 'Support engineer assigned',
    tk.opened_month AS OPENED_MONTH
      WITH SYNONYMS = ('month', 'ticket month')
      COMMENT = 'Month the ticket was opened',
    tk.opened_at AS OPENED_AT
      WITH SYNONYMS = ('open date', 'created date')
      COMMENT = 'Timestamp the ticket was opened'
  )

  METRICS (
    tk.ticket_count AS COUNT(TICKET_ID)
      WITH SYNONYMS = ('number of tickets', 'ticket volume', 'how many tickets', 'cases')
      COMMENT = 'Number of tickets',
    tk.open_ticket_count AS SUM(tk.is_open)
      WITH SYNONYMS = ('open tickets', 'backlog')
      COMMENT = 'Number of open tickets',
    tk.avg_resolution_hours AS AVG(RESOLUTION_HOURS)
      WITH SYNONYMS = ('time to resolve', 'resolution time', 'MTTR')
      COMMENT = 'Average hours to resolve closed tickets',
    tk.sla_met_pct AS 100.0 * SUM(tk.is_sla_met) / NULLIF(SUM(tk.is_closed), 0)
      WITH SYNONYMS = ('SLA attainment', 'SLA compliance', 'SLA met rate')
      COMMENT = 'Percent of closed tickets resolved within SLA',
    tk.avg_csat AS AVG(CSAT_SCORE)
      WITH SYNONYMS = ('CSAT', 'ticket satisfaction', 'support satisfaction')
      COMMENT = 'Average ticket CSAT score (1-5)'
  )

  COMMENT = 'Semantic view for Boston Dynamics customer support tickets: volume, priority, SLA attainment, resolution time and CSAT';

-- ============================================================================
-- Semantic View: Sales Pipeline
-- Grain: OPPORTUNITY_ID
-- ============================================================================
CREATE OR REPLACE SEMANTIC VIEW BD_PIPELINE_SV

  TABLES (
    op AS BD_INTELLIGENCE.ANALYTICS.SALES_PIPELINE
      PRIMARY KEY (OPPORTUNITY_ID)
      WITH SYNONYMS ('pipeline', 'opportunities', 'deals', 'renewals', 'sales pipeline')
      COMMENT = 'Sales opportunities including renewals, expansion, upsell, new site and services'
  )

  FACTS (
    op.open_amount AS IFF(NOT IS_CLOSED, AMOUNT_USD, 0),
    op.open_weighted_amount AS IFF(NOT IS_CLOSED, WEIGHTED_AMOUNT_USD, 0),
    op.won_amount AS IFF(IS_WON, AMOUNT_USD, 0),
    op.won_flag AS IFF(IS_WON, 1, 0),
    op.closed_flag AS IFF(IS_CLOSED, 1, 0)
  )

  DIMENSIONS (
    op.opportunity_id AS OPPORTUNITY_ID
      COMMENT = 'Opportunity identifier',
    op.opportunity_name AS OPPORTUNITY_NAME
      WITH SYNONYMS = ('deal', 'deal name')
      COMMENT = 'Opportunity name',
    op.customer_name AS CUSTOMER_NAME
      WITH SYNONYMS = ('customer', 'account', 'client')
      COMMENT = 'Customer name',
    op.industry AS INDUSTRY
      COMMENT = 'Industry vertical',
    op.segment AS SEGMENT
      COMMENT = 'Customer segment',
    op.region AS REGION
      COMMENT = 'Geographic region',
    op.lifecycle_stage AS LIFECYCLE_STAGE
      COMMENT = 'Customer lifecycle stage',
    op.opportunity_type AS OPPORTUNITY_TYPE
      WITH SYNONYMS = ('deal type', 'type')
      COMMENT = 'Renewal, Expansion, Upsell, New Site, or Services',
    op.product_line AS PRODUCT_LINE
      WITH SYNONYMS = ('product')
      COMMENT = 'Product line: Atlas, Spot, or Stretch',
    op.stage AS STAGE
      WITH SYNONYMS = ('deal stage', 'sales stage')
      COMMENT = 'Discovery, Qualification, Proposal, Negotiation, Commit, Closed Won, Closed Lost',
    op.owner AS OWNER
      WITH SYNONYMS = ('account manager', 'sales rep', 'AE')
      COMMENT = 'Opportunity owner',
    op.close_date AS CLOSE_DATE
      WITH SYNONYMS = ('expected close', 'close')
      COMMENT = 'Expected or actual close date',
    op.close_quarter AS CLOSE_QUARTER
      WITH SYNONYMS = ('quarter')
      COMMENT = 'Quarter of close date',
    op.created_date AS CREATED_DATE
      COMMENT = 'Date the opportunity was created',
    op.is_closed AS IS_CLOSED
      COMMENT = 'True if the opportunity is closed (won or lost)',
    op.is_won AS IS_WON
      COMMENT = 'True if the opportunity was won',
    op.loss_reason AS LOSS_REASON
      WITH SYNONYMS = ('why lost', 'lost reason')
      COMMENT = 'Reason the opportunity was lost'
  )

  METRICS (
    op.opportunity_count AS COUNT(OPPORTUNITY_ID)
      WITH SYNONYMS = ('number of deals', 'deal count', 'how many opportunities')
      COMMENT = 'Number of opportunities',
    op.total_amount_usd AS SUM(AMOUNT_USD)
      WITH SYNONYMS = ('amount', 'deal value', 'pipeline value', 'bookings')
      COMMENT = 'Total opportunity amount in USD',
    op.open_pipeline_usd AS SUM(op.open_amount)
      WITH SYNONYMS = ('open pipeline', 'pipeline')
      COMMENT = 'Amount of open (not closed) opportunities in USD',
    op.weighted_pipeline_usd AS SUM(op.open_weighted_amount)
      WITH SYNONYMS = ('weighted pipeline', 'forecast')
      COMMENT = 'Probability-weighted open pipeline in USD',
    op.won_amount_usd AS SUM(op.won_amount)
      WITH SYNONYMS = ('won', 'closed won', 'bookings won')
      COMMENT = 'Amount of won opportunities in USD',
    op.win_rate_pct AS 100.0 * SUM(op.won_flag) / NULLIF(SUM(op.closed_flag), 0)
      WITH SYNONYMS = ('win rate', 'close rate')
      COMMENT = 'Percent of closed opportunities that were won',
    op.avg_sales_cycle_days AS AVG(SALES_CYCLE_DAYS)
      WITH SYNONYMS = ('sales cycle', 'cycle time')
      COMMENT = 'Average days from creation to close'
  )

  COMMENT = 'Semantic view for Boston Dynamics sales pipeline: renewals, expansion, upsell, new site and services opportunities';

-- ============================================================================
-- Semantic View: Product Usage
-- Grain: CUSTOMER_ID, USAGE_MONTH
-- ============================================================================
CREATE OR REPLACE SEMANTIC VIEW BD_PRODUCT_USAGE_SV

  TABLES (
    us AS BD_INTELLIGENCE.ANALYTICS.CUSTOMER_USAGE_TREND
      PRIMARY KEY (CUSTOMER_ID, USAGE_MONTH)
      WITH SYNONYMS ('usage', 'adoption', 'product usage', 'utilization')
      COMMENT = 'Monthly product adoption per customer: active robots, utilization, operating hours, missions, autonomy'
  )

  DIMENSIONS (
    us.customer_id AS CUSTOMER_ID
      COMMENT = 'Customer identifier',
    us.usage_month AS USAGE_MONTH
      WITH SYNONYMS = ('month', 'period')
      COMMENT = 'Month of usage (first day of month)',
    us.customer_name AS CUSTOMER_NAME
      WITH SYNONYMS = ('customer', 'account', 'client')
      COMMENT = 'Customer name',
    us.industry AS INDUSTRY
      COMMENT = 'Industry vertical',
    us.segment AS SEGMENT
      COMMENT = 'Customer segment',
    us.region AS REGION
      COMMENT = 'Geographic region',
    us.lifecycle_stage AS LIFECYCLE_STAGE
      COMMENT = 'Customer lifecycle stage'
  )

  METRICS (
    us.avg_active_robots AS AVG(AVG_ACTIVE_ROBOTS)
      WITH SYNONYMS = ('active robots', 'robots in use')
      COMMENT = 'Average daily active robots',
    us.utilization_pct AS AVG(UTILIZATION_PCT)
      WITH SYNONYMS = ('utilization', 'adoption rate', 'fleet utilization')
      COMMENT = 'Average daily active robots as a percent of fleet',
    us.operating_hours AS SUM(OPERATING_HOURS)
      WITH SYNONYMS = ('hours', 'run hours', 'operating time')
      COMMENT = 'Total robot operating hours',
    us.missions_completed AS SUM(MISSIONS_COMPLETED)
      WITH SYNONYMS = ('missions', 'tasks completed', 'jobs')
      COMMENT = 'Total missions completed',
    us.avg_autonomy_pct AS AVG(AVG_AUTONOMY_PCT)
      WITH SYNONYMS = ('autonomy', 'autonomous percent')
      COMMENT = 'Average percent of operating time spent autonomously',
    us.avg_features_used AS AVG(AVG_FEATURES_USED)
      WITH SYNONYMS = ('feature adoption', 'features')
      COMMENT = 'Average number of product features used per day',
    us.app_logins AS SUM(APP_LOGINS)
      WITH SYNONYMS = ('logins', 'app usage')
      COMMENT = 'Total app logins'
  )

  COMMENT = 'Semantic view for Boston Dynamics product usage and adoption trends per customer per month';
