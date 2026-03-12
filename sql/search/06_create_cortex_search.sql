/*=============================================================================
  Boston Dynamics Intelligence Agent
  Step 6: Cortex Search Service
  
  Execution Order: 6 of 9
  Description: Creates a Cortex Search service over the knowledge base table
               to enable RAG-based retrieval of technical documentation,
               maintenance procedures, and troubleshooting guides.
=============================================================================*/

USE DATABASE BD_INTELLIGENCE;
USE SCHEMA ANALYTICS;
USE WAREHOUSE BOSTON_DYNAMICS_WH;

CREATE OR REPLACE CORTEX SEARCH SERVICE BD_KNOWLEDGE_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, SUBCATEGORY, ROBOT_MODEL, TAGS
  WAREHOUSE = BOSTON_DYNAMICS_WH
  TARGET_LAG = '1 hour'
  COMMENT = 'Cortex Search service over Boston Dynamics knowledge base including technical documentation, maintenance procedures, troubleshooting guides, and product specifications for Atlas, Spot, and Stretch robots'
AS
  SELECT
    ARTICLE_ID,
    TITLE,
    CATEGORY,
    SUBCATEGORY,
    CONTENT,
    ROBOT_MODEL,
    TAGS,
    AUTHOR,
    CREATED_AT
  FROM BD_INTELLIGENCE.RAW.KNOWLEDGE_BASE;

-- ============================================================================
-- Cortex Search Service 2: Maintenance Records Search
-- Enables RAG-based retrieval over maintenance descriptions, outcomes,
-- parts replaced, and service technician notes.
-- ============================================================================
CREATE OR REPLACE CORTEX SEARCH SERVICE BD_MAINTENANCE_SEARCH
  ON SEARCH_TEXT
  ATTRIBUTES MAINTENANCE_TYPE, ROBOT_MODEL, OUTCOME, PERFORMED_BY
  WAREHOUSE = BOSTON_DYNAMICS_WH
  TARGET_LAG = '1 hour'
  COMMENT = 'Cortex Search service over Boston Dynamics maintenance records including service descriptions, parts replaced, and technician outcomes for Atlas, Spot, and Stretch robots'
AS
  SELECT
    m.MAINTENANCE_ID,
    m.MAINTENANCE_TYPE,
    m.DESCRIPTION || COALESCE(' | Parts replaced: ' || m.PARTS_REPLACED, '') || ' | Outcome: ' || m.OUTCOME AS SEARCH_TEXT,
    r.ROBOT_NAME,
    r.ROBOT_MODEL,
    m.PERFORMED_BY,
    m.OUTCOME,
    m.COST_USD,
    m.DURATION_MINUTES,
    m.PERFORMED_AT
  FROM BD_INTELLIGENCE.RAW.MAINTENANCE_RECORDS m
  JOIN BD_INTELLIGENCE.RAW.ROBOTS r ON m.ROBOT_ID = r.ROBOT_ID;

-- ============================================================================
-- Cortex Search Service 3: Incident Records Search
-- Enables RAG-based retrieval over incident descriptions, resolutions,
-- and root cause analyses for troubleshooting and pattern analysis.
-- ============================================================================
CREATE OR REPLACE CORTEX SEARCH SERVICE BD_INCIDENT_SEARCH
  ON SEARCH_TEXT
  ATTRIBUTES INCIDENT_TYPE, SEVERITY, ROBOT_MODEL, ROOT_CAUSE
  WAREHOUSE = BOSTON_DYNAMICS_WH
  TARGET_LAG = '1 hour'
  COMMENT = 'Cortex Search service over Boston Dynamics incident records including descriptions, resolutions, root causes, and severity classifications for fleet-wide incident analysis'
AS
  SELECT
    i.INCIDENT_ID,
    i.INCIDENT_TYPE,
    i.SEVERITY,
    i.DESCRIPTION || COALESCE(' | Resolution: ' || i.RESOLUTION, '') || COALESCE(' | Root cause: ' || i.ROOT_CAUSE, '') AS SEARCH_TEXT,
    r.ROBOT_NAME,
    r.ROBOT_MODEL,
    i.ROOT_CAUSE,
    i.DOWNTIME_MINUTES,
    i.REPORTED_AT,
    i.RESOLVED_AT
  FROM BD_INTELLIGENCE.RAW.INCIDENTS i
  JOIN BD_INTELLIGENCE.RAW.ROBOTS r ON i.ROBOT_ID = r.ROBOT_ID;
