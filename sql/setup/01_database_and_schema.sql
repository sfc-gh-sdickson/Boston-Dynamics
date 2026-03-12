/*=============================================================================
  Boston Dynamics Intelligence Agent
  Step 1: Database, Schemas, and Warehouse Setup
  
  Execution Order: 1 of 9
  Description: Creates the BD_INTELLIGENCE database with RAW and ANALYTICS 
               schemas, plus the BOSTON_DYNAMICS_WH warehouse.
=============================================================================*/

CREATE DATABASE IF NOT EXISTS BD_INTELLIGENCE;
USE DATABASE BD_INTELLIGENCE;

CREATE SCHEMA IF NOT EXISTS RAW
    COMMENT = 'Raw ingestion layer for robot telemetry, maintenance records, customer data, and knowledge base articles';

CREATE SCHEMA IF NOT EXISTS ANALYTICS
    COMMENT = 'Analytical layer with views, semantic views, ML prediction functions, and agent resources';

CREATE OR REPLACE WAREHOUSE BOSTON_DYNAMICS_WH WITH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for Boston Dynamics Intelligence Agent';

USE WAREHOUSE BOSTON_DYNAMICS_WH;
USE SCHEMA RAW;
