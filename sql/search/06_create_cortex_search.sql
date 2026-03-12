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
