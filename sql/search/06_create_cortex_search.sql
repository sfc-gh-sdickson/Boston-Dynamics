/*=============================================================================
  Boston Dynamics Intelligence Agent
  Step 6: Cortex Search Services
  
  Execution Order: 6 of 9
  Description: Creates six Cortex Search services for RAG retrieval:
               knowledge base, maintenance, incidents, customer interactions,
               support tickets, and NPS/CSAT feedback verbatims.
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

-- ============================================================================
-- CUSTOMER 360 SEARCH SERVICES
-- ============================================================================

-- ============================================================================
-- Cortex Search Service 4: Customer Interactions
-- QBRs, calls, emails, site visits and executive briefings with sentiment.
-- ============================================================================
CREATE OR REPLACE CORTEX SEARCH SERVICE BD_INTERACTION_SEARCH
  ON SEARCH_TEXT
  ATTRIBUTES CUSTOMER_NAME, INDUSTRY, SEGMENT, INTERACTION_TYPE, SENTIMENT, OWNER
  WAREHOUSE = BOSTON_DYNAMICS_WH
  TARGET_LAG = '1 hour'
  COMMENT = 'Cortex Search service over customer interaction notes (QBRs, calls, emails, site visits, executive briefings) with sentiment and next steps'
AS
  SELECT
    n.INTERACTION_ID,
    n.SUBJECT || ' (' || n.INTERACTION_DATE::VARCHAR || '): ' || n.SUMMARY
      || COALESCE(' | Next steps: ' || n.NEXT_STEPS, '') AS SEARCH_TEXT,
    c.CUSTOMER_NAME,
    c.INDUSTRY,
    c.SEGMENT,
    n.INTERACTION_TYPE,
    n.SENTIMENT,
    n.OWNER,
    ct.FULL_NAME AS CONTACT_NAME,
    n.INTERACTION_DATE
  FROM BD_INTELLIGENCE.RAW.INTERACTIONS n
  JOIN BD_INTELLIGENCE.RAW.CUSTOMERS c ON c.CUSTOMER_ID = n.CUSTOMER_ID
  LEFT JOIN BD_INTELLIGENCE.RAW.CONTACTS ct ON ct.CONTACT_ID = n.CONTACT_ID;

-- ============================================================================
-- Cortex Search Service 5: Support Tickets
-- ============================================================================
CREATE OR REPLACE CORTEX SEARCH SERVICE BD_SUPPORT_TICKET_SEARCH
  ON SEARCH_TEXT
  ATTRIBUTES CUSTOMER_NAME, INDUSTRY, SEGMENT, CATEGORY, PRIORITY, STATUS
  WAREHOUSE = BOSTON_DYNAMICS_WH
  TARGET_LAG = '1 hour'
  COMMENT = 'Cortex Search service over customer support tickets including subject, description, priority, SLA and CSAT'
AS
  SELECT
    t.TICKET_ID,
    t.SUBJECT || ': ' || t.DESCRIPTION
      || ' | Priority: ' || t.PRIORITY || ' | Status: ' || t.STATUS
      || COALESCE(' | SLA met: ' || IFF(t.SLA_MET, 'Yes', 'No'), '')
      || COALESCE(' | CSAT: ' || t.CSAT_SCORE::VARCHAR, '') AS SEARCH_TEXT,
    c.CUSTOMER_NAME,
    c.INDUSTRY,
    c.SEGMENT,
    t.CATEGORY,
    t.PRIORITY,
    t.STATUS,
    t.ROBOT_ID,
    t.ASSIGNED_TO,
    t.OPENED_AT,
    t.RESOLUTION_HOURS
  FROM BD_INTELLIGENCE.RAW.SUPPORT_TICKETS t
  JOIN BD_INTELLIGENCE.RAW.CUSTOMERS c ON c.CUSTOMER_ID = t.CUSTOMER_ID;

-- ============================================================================
-- Cortex Search Service 6: Customer Feedback (NPS / CSAT verbatims)
-- ============================================================================
CREATE OR REPLACE CORTEX SEARCH SERVICE BD_CUSTOMER_FEEDBACK_SEARCH
  ON SEARCH_TEXT
  ATTRIBUTES CUSTOMER_NAME, INDUSTRY, SEGMENT, SURVEY_TYPE, NPS_CATEGORY
  WAREHOUSE = BOSTON_DYNAMICS_WH
  TARGET_LAG = '1 hour'
  COMMENT = 'Cortex Search service over NPS and CSAT survey verbatim comments with score and category'
AS
  SELECT
    s.SURVEY_ID,
    s.SURVEY_TYPE || ' ' || s.SCORE::VARCHAR || ' (' || s.NPS_CATEGORY || ') from '
      || COALESCE(ct.FULL_NAME || ', ' || ct.CONTACT_ROLE, 'customer contact') || ' at ' || c.CUSTOMER_NAME
      || ' on ' || s.RESPONSE_DATE::VARCHAR || ': ' || s.VERBATIM AS SEARCH_TEXT,
    c.CUSTOMER_NAME,
    c.INDUSTRY,
    c.SEGMENT,
    s.SURVEY_TYPE,
    s.NPS_CATEGORY,
    s.SCORE,
    s.RESPONSE_DATE
  FROM BD_INTELLIGENCE.RAW.SURVEYS s
  JOIN BD_INTELLIGENCE.RAW.CUSTOMERS c ON c.CUSTOMER_ID = s.CUSTOMER_ID
  LEFT JOIN BD_INTELLIGENCE.RAW.CONTACTS ct ON ct.CONTACT_ID = s.CONTACT_ID;
