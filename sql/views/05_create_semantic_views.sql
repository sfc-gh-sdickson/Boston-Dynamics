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
  COMMENT = 'Semantic view for Boston Dynamics fleet operations including robots, deployments, customers, components, and overall fleet health'
AS
  SELECT
    fo.ROBOT_ID
      COMMENT = 'Unique identifier for each robot in the fleet',
    fo.ROBOT_NAME
      WITH SYNONYMS ('robot', 'bot', 'unit')
      COMMENT = 'Human-readable name of the robot including model prefix',
    fo.ROBOT_MODEL
      WITH SYNONYMS ('model', 'type', 'robot type', 'platform')
      COMMENT = 'Robot model: Atlas (humanoid), Spot (quadruped), or Stretch (warehouse)',
    fo.SERIAL_NUMBER
      COMMENT = 'Manufacturing serial number for the robot',
    fo.ROBOT_STATUS
      WITH SYNONYMS ('status', 'state', 'condition', 'operational status')
      COMMENT = 'Current robot status: Active, Idle, Maintenance, or Decommissioned',
    fo.FIRMWARE_VERSION
      WITH SYNONYMS ('firmware', 'software version', 'version')
      COMMENT = 'Currently installed firmware version',
    fo.MANUFACTURE_DATE
      WITH SYNONYMS ('build date', 'production date', 'manufactured')
      COMMENT = 'Date the robot was manufactured',
    fo.AGE_DAYS
      WITH SYNONYMS ('age', 'days old', 'robot age')
      COMMENT = 'Number of days since the robot was manufactured',
    fo.SITE_NAME
      WITH SYNONYMS ('site', 'location', 'deployment site', 'facility')
      COMMENT = 'Name of the deployment site where the robot operates',
    fo.SITE_TYPE
      WITH SYNONYMS ('facility type', 'location type')
      COMMENT = 'Type of deployment site: Manufacturing Floor, Warehouse, Outdoor, etc.',
    fo.PRIMARY_USE_CASE
      WITH SYNONYMS ('use case', 'application', 'purpose', 'task')
      COMMENT = 'Primary operational use case at the deployment site',
    fo.DEPLOYMENT_ENVIRONMENT
      WITH SYNONYMS ('environment', 'operating environment')
      COMMENT = 'Operating environment: Indoor, Outdoor, Mixed, or Hazardous',
    fo.CUSTOMER_NAME
      WITH SYNONYMS ('customer', 'client', 'account', 'company')
      COMMENT = 'Name of the customer organization',
    fo.CUSTOMER_INDUSTRY
      WITH SYNONYMS ('industry', 'sector', 'vertical')
      COMMENT = 'Industry vertical of the customer',
    fo.CUSTOMER_REGION
      WITH SYNONYMS ('region', 'geography', 'area')
      COMMENT = 'Geographic region of the customer',
    fo.SUPPORT_TIER
      WITH SYNONYMS ('support level', 'service tier', 'SLA tier')
      COMMENT = 'Customer support tier: Platinum, Gold, Silver, or Bronze',
    fo.TOTAL_COMPONENTS
      WITH SYNONYMS ('component count', 'parts count', 'number of components')
      COMMENT = 'Total number of components installed on the robot',
    fo.HEALTHY_COMPONENTS
      WITH SYNONYMS ('working components', 'operational components', 'good components')
      COMMENT = 'Number of components in Operational status',
    fo.DEGRADED_COMPONENTS
      WITH SYNONYMS ('worn components', 'aging components')
      COMMENT = 'Number of components in Degraded status',
    fo.CRITICAL_COMPONENTS
      WITH SYNONYMS ('failing components', 'bad components', 'components needing replacement')
      COMMENT = 'Number of components that are Failed or Need Replacement'
  FROM BD_INTELLIGENCE.ANALYTICS.FLEET_OVERVIEW fo;

-- ============================================================================
-- Semantic View: Telemetry Analytics
-- Enables questions about robot telemetry, sensor data, and performance
-- ============================================================================
CREATE OR REPLACE SEMANTIC VIEW BD_TELEMETRY_ANALYTICS_SV
  COMMENT = 'Semantic view for Boston Dynamics robot telemetry data including battery, temperature, vibration, speed, and error metrics'
AS
  SELECT
    ts.ROBOT_ID
      COMMENT = 'Unique identifier for the robot',
    ts.ROBOT_NAME
      WITH SYNONYMS ('robot', 'bot', 'unit')
      COMMENT = 'Name of the robot',
    ts.ROBOT_MODEL
      WITH SYNONYMS ('model', 'type', 'platform')
      COMMENT = 'Robot model: Atlas, Spot, or Stretch',
    ts.TELEMETRY_DATE
      WITH SYNONYMS ('date', 'day', 'reading date')
      COMMENT = 'Date of the telemetry readings',
    ts.READING_COUNT
      WITH SYNONYMS ('readings', 'data points', 'samples')
      COMMENT = 'Number of telemetry readings recorded on this date',
    ts.AVG_BATTERY_LEVEL
      WITH SYNONYMS ('battery', 'charge level', 'power level', 'battery percentage')
      COMMENT = 'Average battery level percentage for the day',
    ts.MIN_BATTERY_LEVEL
      WITH SYNONYMS ('lowest battery', 'minimum charge')
      COMMENT = 'Minimum battery level recorded during the day',
    ts.AVG_CPU_TEMP_C
      WITH SYNONYMS ('cpu temperature', 'processor temperature', 'cpu heat')
      COMMENT = 'Average CPU temperature in Celsius',
    ts.MAX_CPU_TEMP_C
      WITH SYNONYMS ('peak cpu temp', 'highest cpu temperature')
      COMMENT = 'Maximum CPU temperature in Celsius',
    ts.AVG_MOTOR_TEMP_C
      WITH SYNONYMS ('motor temperature', 'motor heat', 'actuator temperature')
      COMMENT = 'Average motor temperature in Celsius',
    ts.MAX_MOTOR_TEMP_C
      WITH SYNONYMS ('peak motor temp', 'highest motor temperature')
      COMMENT = 'Maximum motor temperature in Celsius',
    ts.AVG_VIBRATION
      WITH SYNONYMS ('vibration', 'vibration level', 'shake')
      COMMENT = 'Average vibration level in mm/s',
    ts.MAX_VIBRATION
      WITH SYNONYMS ('peak vibration', 'maximum vibration')
      COMMENT = 'Maximum vibration level in mm/s',
    ts.AVG_JOINT_LOAD
      WITH SYNONYMS ('joint load', 'load percentage', 'joint stress')
      COMMENT = 'Average joint load as percentage of maximum capacity',
    ts.MAX_JOINT_LOAD
      WITH SYNONYMS ('peak load', 'maximum joint load')
      COMMENT = 'Maximum joint load percentage recorded',
    ts.AVG_SPEED_M_S
      WITH SYNONYMS ('speed', 'velocity', 'movement speed')
      COMMENT = 'Average movement speed in meters per second',
    ts.MAX_SPEED_M_S
      WITH SYNONYMS ('top speed', 'maximum speed', 'peak speed')
      COMMENT = 'Maximum speed recorded in meters per second',
    ts.ERROR_COUNT
      WITH SYNONYMS ('errors', 'faults', 'error occurrences')
      COMMENT = 'Number of error codes recorded during the day',
    ts.DISTINCT_MODES
      WITH SYNONYMS ('operational modes', 'modes used')
      COMMENT = 'Number of distinct operational modes used during the day'
  FROM BD_INTELLIGENCE.ANALYTICS.TELEMETRY_DAILY_SUMMARY ts;

-- ============================================================================
-- Semantic View: Maintenance Intelligence
-- Enables questions about maintenance history, costs, and scheduling
-- ============================================================================
CREATE OR REPLACE SEMANTIC VIEW BD_MAINTENANCE_INTELLIGENCE_SV
  COMMENT = 'Semantic view for Boston Dynamics maintenance records including costs, frequency, duration, and scheduling across the robot fleet'
AS
  SELECT
    ma.ROBOT_ID
      COMMENT = 'Robot identifier',
    ma.ROBOT_NAME
      WITH SYNONYMS ('robot', 'bot', 'unit')
      COMMENT = 'Name of the robot',
    ma.ROBOT_MODEL
      WITH SYNONYMS ('model', 'type', 'platform')
      COMMENT = 'Robot model: Atlas, Spot, or Stretch',
    ma.SITE_NAME
      WITH SYNONYMS ('site', 'location', 'facility')
      COMMENT = 'Deployment site name',
    ma.CUSTOMER_NAME
      WITH SYNONYMS ('customer', 'client', 'account')
      COMMENT = 'Customer organization name',
    ma.MAINTENANCE_TYPE
      WITH SYNONYMS ('type', 'service type', 'maintenance category')
      COMMENT = 'Type of maintenance: Preventive, Corrective, Predictive, Firmware Update, or Calibration',
    ma.MAINTENANCE_COUNT
      WITH SYNONYMS ('count', 'frequency', 'number of events', 'how many')
      COMMENT = 'Total number of maintenance events',
    ma.TOTAL_COST_USD
      WITH SYNONYMS ('total cost', 'cost', 'expense', 'spending', 'money spent')
      COMMENT = 'Total maintenance cost in US dollars',
    ma.AVG_COST_USD
      WITH SYNONYMS ('average cost', 'cost per event')
      COMMENT = 'Average cost per maintenance event in US dollars',
    ma.AVG_DURATION_MINUTES
      WITH SYNONYMS ('average duration', 'time per event', 'average time')
      COMMENT = 'Average duration of maintenance events in minutes',
    ma.TOTAL_DURATION_MINUTES
      WITH SYNONYMS ('total time', 'total duration', 'hours spent')
      COMMENT = 'Total time spent on maintenance in minutes',
    ma.FIRST_MAINTENANCE_DATE
      WITH SYNONYMS ('first service', 'earliest maintenance')
      COMMENT = 'Date of the first maintenance event',
    ma.LAST_MAINTENANCE_DATE
      WITH SYNONYMS ('last service', 'most recent maintenance', 'latest maintenance')
      COMMENT = 'Date of the most recent maintenance event',
    ma.PARTS_REPLACEMENT_COUNT
      WITH SYNONYMS ('parts replaced', 'replacement count', 'components swapped')
      COMMENT = 'Number of maintenance events that involved replacing parts'
  FROM BD_INTELLIGENCE.ANALYTICS.MAINTENANCE_ANALYSIS ma;

-- ============================================================================
-- Semantic View: Incident Analysis
-- Enables questions about incidents, downtime, and safety events
-- ============================================================================
CREATE OR REPLACE SEMANTIC VIEW BD_INCIDENT_ANALYSIS_SV
  COMMENT = 'Semantic view for Boston Dynamics incident tracking including incident types, severity, downtime, and resolution status'
AS
  SELECT
    id.ROBOT_ID
      COMMENT = 'Robot identifier',
    id.ROBOT_NAME
      WITH SYNONYMS ('robot', 'bot', 'unit')
      COMMENT = 'Name of the robot',
    id.ROBOT_MODEL
      WITH SYNONYMS ('model', 'type', 'platform')
      COMMENT = 'Robot model: Atlas, Spot, or Stretch',
    id.SITE_NAME
      WITH SYNONYMS ('site', 'location', 'facility')
      COMMENT = 'Deployment site where incidents occurred',
    id.CUSTOMER_NAME
      WITH SYNONYMS ('customer', 'client', 'account')
      COMMENT = 'Customer organization name',
    id.CUSTOMER_INDUSTRY
      WITH SYNONYMS ('industry', 'sector')
      COMMENT = 'Industry vertical of the customer',
    id.INCIDENT_TYPE
      WITH SYNONYMS ('type', 'incident category', 'failure type', 'issue type')
      COMMENT = 'Category of incident: Hardware Failure, Software Error, Communication Loss, etc.',
    id.SEVERITY
      WITH SYNONYMS ('priority', 'criticality', 'impact level')
      COMMENT = 'Incident severity: Critical, High, Medium, or Low',
    id.INCIDENT_COUNT
      WITH SYNONYMS ('count', 'number of incidents', 'how many incidents', 'occurrences')
      COMMENT = 'Total number of incidents',
    id.TOTAL_DOWNTIME_MINUTES
      WITH SYNONYMS ('downtime', 'total downtime', 'outage time', 'unavailable time')
      COMMENT = 'Total downtime caused by incidents in minutes',
    id.AVG_DOWNTIME_MINUTES
      WITH SYNONYMS ('average downtime', 'mean downtime')
      COMMENT = 'Average downtime per incident in minutes',
    id.RESOLVED_COUNT
      WITH SYNONYMS ('resolved', 'fixed', 'closed')
      COMMENT = 'Number of incidents that have been resolved',
    id.UNRESOLVED_COUNT
      WITH SYNONYMS ('unresolved', 'open', 'pending', 'outstanding')
      COMMENT = 'Number of incidents still open or unresolved',
    id.FIRST_INCIDENT_DATE
      WITH SYNONYMS ('first incident', 'earliest incident')
      COMMENT = 'Date of the first incident',
    id.LAST_INCIDENT_DATE
      WITH SYNONYMS ('last incident', 'most recent incident', 'latest incident')
      COMMENT = 'Date of the most recent incident'
  FROM BD_INTELLIGENCE.ANALYTICS.INCIDENT_DASHBOARD id;
