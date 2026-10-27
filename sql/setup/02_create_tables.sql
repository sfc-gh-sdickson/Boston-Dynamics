/*=============================================================================
  Boston Dynamics Intelligence Agent
  Step 2: Table Definitions
  
  Execution Order: 2 of 9
  Description: Creates all tables in the RAW schema for robot telemetry,
               maintenance, components, customers, deployments, incidents,
               and the knowledge base, plus Customer 360 tables (contacts,
               contracts, invoices, support tickets, surveys, product usage,
               opportunities, interactions).
=============================================================================*/

USE DATABASE BD_INTELLIGENCE;
USE SCHEMA RAW;
USE WAREHOUSE BOSTON_DYNAMICS_WH;

CREATE OR REPLACE TABLE ROBOTS (
    ROBOT_ID            VARCHAR(50)     NOT NULL,
    ROBOT_NAME          VARCHAR(100)    NOT NULL,
    ROBOT_MODEL         VARCHAR(50)     NOT NULL,
    SERIAL_NUMBER       VARCHAR(100)    NOT NULL,
    MANUFACTURE_DATE    DATE            NOT NULL,
    FIRMWARE_VERSION    VARCHAR(30),
    STATUS              VARCHAR(20)     NOT NULL,
    DEPLOYMENT_ID       VARCHAR(50),
    CREATED_AT          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_ROBOTS PRIMARY KEY (ROBOT_ID)
);

CREATE OR REPLACE TABLE ROBOT_TELEMETRY (
    TELEMETRY_ID        VARCHAR(50)     NOT NULL,
    ROBOT_ID            VARCHAR(50)     NOT NULL,
    TIMESTAMP           TIMESTAMP_NTZ   NOT NULL,
    BATTERY_LEVEL       FLOAT,
    CPU_TEMPERATURE_C   FLOAT,
    MOTOR_TEMPERATURE_C FLOAT,
    VIBRATION_MM_S      FLOAT,
    JOINT_LOAD_PERCENT  FLOAT,
    SPEED_M_S           FLOAT,
    ORIENTATION_ROLL    FLOAT,
    ORIENTATION_PITCH   FLOAT,
    ORIENTATION_YAW     FLOAT,
    LOCATION_X          FLOAT,
    LOCATION_Y          FLOAT,
    LOCATION_Z          FLOAT,
    OPERATIONAL_MODE    VARCHAR(30),
    ERROR_CODE          VARCHAR(20),
    CONSTRAINT PK_TELEMETRY PRIMARY KEY (TELEMETRY_ID)
);

CREATE OR REPLACE TABLE COMPONENTS (
    COMPONENT_ID        VARCHAR(50)     NOT NULL,
    ROBOT_ID            VARCHAR(50)     NOT NULL,
    COMPONENT_TYPE      VARCHAR(50)     NOT NULL,
    COMPONENT_NAME      VARCHAR(100)    NOT NULL,
    INSTALL_DATE        DATE            NOT NULL,
    EXPECTED_LIFESPAN_DAYS  INTEGER,
    CURRENT_RUNTIME_HOURS   FLOAT       DEFAULT 0,
    STATUS              VARCHAR(20)     NOT NULL,
    LAST_INSPECTION_DATE    DATE,
    INSPECTION_RUL_DAYS     INTEGER,    -- field engineer remaining-useful-life estimate at last inspection
    CONSTRAINT PK_COMPONENTS PRIMARY KEY (COMPONENT_ID)
);

CREATE OR REPLACE TABLE MAINTENANCE_RECORDS (
    MAINTENANCE_ID      VARCHAR(50)     NOT NULL,
    ROBOT_ID            VARCHAR(50)     NOT NULL,
    COMPONENT_ID        VARCHAR(50),
    MAINTENANCE_TYPE    VARCHAR(30)     NOT NULL,
    DESCRIPTION         VARCHAR(2000),
    PERFORMED_BY        VARCHAR(100),
    PERFORMED_AT        TIMESTAMP_NTZ   NOT NULL,
    DURATION_MINUTES    INTEGER,
    COST_USD            FLOAT,
    PARTS_REPLACED      VARCHAR(500),
    OUTCOME             VARCHAR(30),
    NEXT_SCHEDULED      DATE,
    CONSTRAINT PK_MAINTENANCE PRIMARY KEY (MAINTENANCE_ID)
);

CREATE OR REPLACE TABLE CUSTOMERS (
    CUSTOMER_ID         VARCHAR(50)     NOT NULL,
    CUSTOMER_NAME       VARCHAR(200)    NOT NULL,
    INDUSTRY            VARCHAR(100),
    COMPANY_SIZE        VARCHAR(30),
    REGION              VARCHAR(50),
    COUNTRY             VARCHAR(50),
    CONTRACT_START_DATE DATE,
    CONTRACT_END_DATE   DATE,
    ACCOUNT_MANAGER     VARCHAR(100),
    SUPPORT_TIER        VARCHAR(20),
    -- Customer 360 enrichment
    SEGMENT             VARCHAR(30),
    ANNUAL_REVENUE_USD  NUMBER(18,0),
    EMPLOYEE_COUNT      INTEGER,
    CUSTOMER_SINCE      DATE,
    CSM_NAME            VARCHAR(100),
    HQ_CITY             VARCHAR(100),
    LIFECYCLE_STAGE     VARCHAR(30),
    CONSTRAINT PK_CUSTOMERS PRIMARY KEY (CUSTOMER_ID)
);

CREATE OR REPLACE TABLE DEPLOYMENTS (
    DEPLOYMENT_ID       VARCHAR(50)     NOT NULL,
    CUSTOMER_ID         VARCHAR(50)     NOT NULL,
    SITE_NAME           VARCHAR(200)    NOT NULL,
    SITE_TYPE           VARCHAR(50),
    DEPLOYMENT_DATE     DATE            NOT NULL,
    ROBOT_COUNT         INTEGER,
    PRIMARY_USE_CASE    VARCHAR(200),
    ENVIRONMENT         VARCHAR(50),
    STATUS              VARCHAR(20),
    LATITUDE            FLOAT,
    LONGITUDE           FLOAT,
    CONSTRAINT PK_DEPLOYMENTS PRIMARY KEY (DEPLOYMENT_ID)
);

CREATE OR REPLACE TABLE INCIDENTS (
    INCIDENT_ID         VARCHAR(50)     NOT NULL,
    ROBOT_ID            VARCHAR(50)     NOT NULL,
    DEPLOYMENT_ID       VARCHAR(50),
    INCIDENT_TYPE       VARCHAR(50)     NOT NULL,
    SEVERITY            VARCHAR(20)     NOT NULL,
    DESCRIPTION         VARCHAR(2000),
    REPORTED_AT         TIMESTAMP_NTZ   NOT NULL,
    RESOLVED_AT         TIMESTAMP_NTZ,
    RESOLUTION          VARCHAR(2000),
    ROOT_CAUSE          VARCHAR(500),
    DOWNTIME_MINUTES    INTEGER,
    CONSTRAINT PK_INCIDENTS PRIMARY KEY (INCIDENT_ID)
);

CREATE OR REPLACE TABLE KNOWLEDGE_BASE (
    ARTICLE_ID          VARCHAR(50)     NOT NULL,
    TITLE               VARCHAR(500)    NOT NULL,
    CATEGORY            VARCHAR(50)     NOT NULL,
    SUBCATEGORY         VARCHAR(100),
    CONTENT             VARCHAR(16000)  NOT NULL,
    ROBOT_MODEL         VARCHAR(50),
    TAGS                VARCHAR(500),
    AUTHOR              VARCHAR(100),
    CREATED_AT          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_KNOWLEDGE_BASE PRIMARY KEY (ARTICLE_ID)
);

CREATE OR REPLACE TABLE FIRMWARE_RELEASES (
    RELEASE_ID          VARCHAR(50)     NOT NULL,
    VERSION             VARCHAR(30)     NOT NULL,
    ROBOT_MODEL         VARCHAR(50)     NOT NULL,
    RELEASE_DATE        DATE            NOT NULL,
    RELEASE_NOTES       VARCHAR(4000),
    IS_CRITICAL         BOOLEAN         DEFAULT FALSE,
    AFFECTED_COMPONENTS VARCHAR(500),
    CONSTRAINT PK_FIRMWARE PRIMARY KEY (RELEASE_ID)
);

-- ============================================================================
-- CUSTOMER 360 TABLES
-- ============================================================================

CREATE OR REPLACE TABLE CONTACTS (
    CONTACT_ID          VARCHAR(50)     NOT NULL,
    CUSTOMER_ID         VARCHAR(50)     NOT NULL,
    FULL_NAME           VARCHAR(200)    NOT NULL,
    TITLE               VARCHAR(200),
    CONTACT_ROLE        VARCHAR(50),
    EMAIL               VARCHAR(200),
    PHONE               VARCHAR(50),
    IS_PRIMARY          BOOLEAN         DEFAULT FALSE,
    CONSTRAINT PK_CONTACTS PRIMARY KEY (CONTACT_ID)
);

CREATE OR REPLACE TABLE CONTRACTS (
    CONTRACT_ID         VARCHAR(50)     NOT NULL,
    CUSTOMER_ID         VARCHAR(50)     NOT NULL,
    CONTRACT_TYPE       VARCHAR(50)     NOT NULL,
    PRODUCT_LINE        VARCHAR(50),
    START_DATE          DATE            NOT NULL,
    END_DATE            DATE            NOT NULL,
    ARR_USD             NUMBER(18,2),
    TCV_USD             NUMBER(18,2),
    ROBOT_QUANTITY      INTEGER,
    AUTO_RENEW          BOOLEAN,
    STATUS              VARCHAR(30)     NOT NULL,
    CONSTRAINT PK_CONTRACTS PRIMARY KEY (CONTRACT_ID)
);

CREATE OR REPLACE TABLE INVOICES (
    INVOICE_ID          VARCHAR(50)     NOT NULL,
    CONTRACT_ID         VARCHAR(50)     NOT NULL,
    CUSTOMER_ID         VARCHAR(50)     NOT NULL,
    INVOICE_DATE        DATE            NOT NULL,
    DUE_DATE            DATE            NOT NULL,
    AMOUNT_USD          NUMBER(18,2)    NOT NULL,
    PAID_DATE           DATE,
    PAYMENT_STATUS      VARCHAR(20)     NOT NULL,
    DAYS_LATE           INTEGER,
    CONSTRAINT PK_INVOICES PRIMARY KEY (INVOICE_ID)
);

CREATE OR REPLACE TABLE SUPPORT_TICKETS (
    TICKET_ID           VARCHAR(50)     NOT NULL,
    CUSTOMER_ID         VARCHAR(50)     NOT NULL,
    CONTACT_ID          VARCHAR(50),
    ROBOT_ID            VARCHAR(50),
    CATEGORY            VARCHAR(50)     NOT NULL,
    PRIORITY            VARCHAR(20)     NOT NULL,
    CHANNEL             VARCHAR(30),
    SUBJECT             VARCHAR(500),
    DESCRIPTION         VARCHAR(4000),
    STATUS              VARCHAR(20)     NOT NULL,
    OPENED_AT           TIMESTAMP_NTZ   NOT NULL,
    CLOSED_AT           TIMESTAMP_NTZ,
    RESOLUTION_HOURS    FLOAT,
    SLA_MET             BOOLEAN,
    CSAT_SCORE          INTEGER,
    ASSIGNED_TO         VARCHAR(100),
    CONSTRAINT PK_SUPPORT_TICKETS PRIMARY KEY (TICKET_ID)
);

CREATE OR REPLACE TABLE SURVEYS (
    SURVEY_ID           VARCHAR(50)     NOT NULL,
    CUSTOMER_ID         VARCHAR(50)     NOT NULL,
    CONTACT_ID          VARCHAR(50),
    SURVEY_TYPE         VARCHAR(20)     NOT NULL,
    SCORE               INTEGER         NOT NULL,
    NPS_CATEGORY        VARCHAR(20),
    VERBATIM            VARCHAR(4000),
    RESPONSE_DATE       DATE            NOT NULL,
    CONSTRAINT PK_SURVEYS PRIMARY KEY (SURVEY_ID)
);

CREATE OR REPLACE TABLE PRODUCT_USAGE_DAILY (
    CUSTOMER_ID         VARCHAR(50)     NOT NULL,
    USAGE_DATE          DATE            NOT NULL,
    ACTIVE_ROBOTS       INTEGER,
    OPERATING_HOURS     FLOAT,
    MISSIONS_COMPLETED  INTEGER,
    AUTONOMY_PCT        FLOAT,
    FEATURES_USED       INTEGER,
    APP_LOGINS          INTEGER,
    CONSTRAINT PK_PRODUCT_USAGE PRIMARY KEY (CUSTOMER_ID, USAGE_DATE)
);

CREATE OR REPLACE TABLE OPPORTUNITIES (
    OPPORTUNITY_ID      VARCHAR(50)     NOT NULL,
    CUSTOMER_ID         VARCHAR(50)     NOT NULL,
    OPPORTUNITY_NAME    VARCHAR(300),
    OPPORTUNITY_TYPE    VARCHAR(30)     NOT NULL,
    PRODUCT_LINE        VARCHAR(50),
    STAGE               VARCHAR(30)     NOT NULL,
    AMOUNT_USD          NUMBER(18,2),
    PROBABILITY_PCT     INTEGER,
    CREATED_DATE        DATE,
    CLOSE_DATE          DATE,
    OWNER               VARCHAR(100),
    IS_CLOSED           BOOLEAN,
    IS_WON              BOOLEAN,
    LOSS_REASON         VARCHAR(200),
    CONSTRAINT PK_OPPORTUNITIES PRIMARY KEY (OPPORTUNITY_ID)
);

CREATE OR REPLACE TABLE INTERACTIONS (
    INTERACTION_ID      VARCHAR(50)     NOT NULL,
    CUSTOMER_ID         VARCHAR(50)     NOT NULL,
    CONTACT_ID          VARCHAR(50),
    INTERACTION_TYPE    VARCHAR(30)     NOT NULL,
    INTERACTION_DATE    DATE            NOT NULL,
    OWNER               VARCHAR(100),
    SUBJECT             VARCHAR(500),
    SUMMARY             VARCHAR(8000),
    SENTIMENT           VARCHAR(20),
    NEXT_STEPS          VARCHAR(2000),
    CONSTRAINT PK_INTERACTIONS PRIMARY KEY (INTERACTION_ID)
);

-- @comments-begin (generated by scripts/build_comments.py; do not edit by hand)
COMMENT ON TABLE BD_INTELLIGENCE.RAW.COMPONENTS IS 'Major components installed on each robot (3,000 rows, about 5 per robot): type, install date, rated lifespan, runtime, condition status and the remaining useful life estimated at the last inspection. Status and RUL derive from a hidden wear index. Synthetic demo data.';
ALTER TABLE BD_INTELLIGENCE.RAW.COMPONENTS ALTER
    COMPONENT_ID COMMENT 'Unique component identifier (COMP-00000 format). Primary key.',
    ROBOT_ID COMMENT 'Robot identifier (BOT-00000 format). Joins to RAW.ROBOTS.',
    COMPONENT_TYPE COMMENT 'Component category: Motor, Battery, Sensor, LiDAR, Camera, Joint Actuator, Hydraulic Pump, Gripper, Controller Board or Communication Module.',
    COMPONENT_NAME COMMENT 'Specific component name (for example Knee Motor, Precision Gripper).',
    INSTALL_DATE COMMENT 'Date the component was installed on the robot.',
    EXPECTED_LIFESPAN_DAYS COMMENT 'Rated design lifespan of the component in days (365-3,991).',
    CURRENT_RUNTIME_HOURS COMMENT 'Cumulative operating hours on the component since installation.',
    STATUS COMMENT 'Condition at last inspection: Operational, Degraded, Needs Replacement or Failed.',
    LAST_INSPECTION_DATE COMMENT 'Date of the most recent technician inspection of the component.',
    INSPECTION_RUL_DAYS COMMENT 'Remaining useful life in days estimated at the last inspection from observed wear (0 = worn out). Target of the BD_REMAINING_USEFUL_LIFE model. Unlike EXPECTED_LIFESPAN_DAYS minus age, it reflects actual condition.';
COMMENT ON TABLE BD_INTELLIGENCE.RAW.CONTACTS IS 'Customer stakeholders (400 rows, 4 per account) with title, buying role, contact details and primary-contact flag. Names repeat across accounts. Emails and phone numbers are fabricated. Synthetic demo data.';
ALTER TABLE BD_INTELLIGENCE.RAW.CONTACTS ALTER
    CONTACT_ID COMMENT 'Unique contact identifier (CON-00000 format). Primary key.',
    CUSTOMER_ID COMMENT 'Customer account identifier (CUST-0000 format). Joins to RAW.CUSTOMERS.',
    FULL_NAME COMMENT 'Contact''s full name. Names repeat across accounts in the synthetic data.',
    TITLE COMMENT 'Contact''s job title.',
    CONTACT_ROLE COMMENT 'Buying-group role: Champion, Economic Buyer, Technical User or Procurement.',
    EMAIL COMMENT 'Contact email address (fabricated).',
    PHONE COMMENT 'Contact phone number (fabricated, +1-555 numbers).',
    IS_PRIMARY COMMENT 'TRUE for the account''s primary contact.';
COMMENT ON TABLE BD_INTELLIGENCE.RAW.CONTRACTS IS 'Commercial agreements (219 rows): annual terms of RaaS subscriptions, purchase + support and leases, plus separate Expansion contracts. Each row has ARR, total contract value, robot quantity and status (Active, Renewed, Churned). Synthetic demo data.';
ALTER TABLE BD_INTELLIGENCE.RAW.CONTRACTS ALTER
    CONTRACT_ID COMMENT 'Unique contract identifier (CTR-00000 format). Primary key.',
    CUSTOMER_ID COMMENT 'Customer account identifier (CUST-0000 format). Joins to RAW.CUSTOMERS.',
    CONTRACT_TYPE COMMENT 'Commercial model: RaaS Subscription (robots-as-a-service), Purchase + Support, Lease, or Expansion (add-on to an existing agreement).',
    PRODUCT_LINE COMMENT 'Robot product line covered: Atlas, Spot or Stretch.',
    START_DATE COMMENT 'Start date of the contract term.',
    END_DATE COMMENT 'End date of the contract term.',
    ARR_USD COMMENT 'Annual recurring revenue of the contract in US dollars.',
    TCV_USD COMMENT 'Total contract value over the full term in US dollars.',
    ROBOT_QUANTITY COMMENT 'Number of robots covered by the contract.',
    AUTO_RENEW COMMENT 'TRUE if the contract renews automatically at term end.',
    STATUS COMMENT 'Contract status: Active (current term), Renewed (a past term that was renewed) or Churned (ended without renewal).';
COMMENT ON TABLE BD_INTELLIGENCE.RAW.CUSTOMERS IS 'One row per Boston Dynamics customer account (100 accounts). Firmographics, segment, account team, contract window and lifecycle stage. Lifecycle stage drives the correlated signals in every Customer 360 table (healthy, expanding, at risk, churned). Synthetic demo data.';
ALTER TABLE BD_INTELLIGENCE.RAW.CUSTOMERS ALTER
    CUSTOMER_ID COMMENT 'Unique customer account identifier (CUST-0000 format). Primary key.',
    CUSTOMER_NAME COMMENT 'Customer company name (for example Siemens Energy, Tesla Gigafactory).',
    INDUSTRY COMMENT 'Customer industry: Automotive Manufacturing, Logistics & Warehousing, Energy & Utilities, Aerospace & Defense, Industrial Manufacturing or Mining & Resources.',
    COMPANY_SIZE COMMENT 'Legacy size band: Enterprise, Large or Mid-Market. Prefer SEGMENT for Customer 360 analysis.',
    REGION COMMENT 'Customer headquarters region: North America, Europe, Asia Pacific, South America or Middle East & Africa.',
    COUNTRY COMMENT 'Country of the customer headquarters.',
    CONTRACT_START_DATE COMMENT 'Start date of the customer''s current (or final, if churned) contract term.',
    CONTRACT_END_DATE COMMENT 'End date of the current contract term, i.e. the next renewal date. For churned customers, the churn date.',
    ACCOUNT_MANAGER COMMENT 'Boston Dynamics account executive who owns the commercial relationship.',
    SUPPORT_TIER COMMENT 'Purchased support entitlement: Platinum, Gold, Silver or Bronze. Higher tiers have tighter SLAs.',
    SEGMENT COMMENT 'Go-to-market segment based on annual revenue: Strategic (largest), Enterprise or Commercial.',
    ANNUAL_REVENUE_USD COMMENT 'Customer company annual revenue in US dollars (the customer''s own revenue, not spend with Boston Dynamics). Log-uniform between about $2B and $386B.',
    EMPLOYEE_COUNT COMMENT 'Approximate number of employees at the customer company.',
    CUSTOMER_SINCE COMMENT 'Date the customer signed its first contract with Boston Dynamics.',
    CSM_NAME COMMENT 'Customer Success Manager assigned to the account.',
    HQ_CITY COMMENT 'City of the customer headquarters.',
    LIFECYCLE_STAGE COMMENT 'Account lifecycle stage: Onboarding, Adopting, Mature, Renewal Due or Churned. Churned accounts have no active contract.';
COMMENT ON TABLE BD_INTELLIGENCE.RAW.DEPLOYMENTS IS 'One row per customer deployment site (200 sites). Each site belongs to one customer and hosts one or more robots. ROBOT_COUNT is reconciled to the number of rows in ROBOTS. Synthetic demo data.';
ALTER TABLE BD_INTELLIGENCE.RAW.DEPLOYMENTS ALTER
    DEPLOYMENT_ID COMMENT 'Unique deployment site identifier (DEP-0000 format). Primary key.',
    CUSTOMER_ID COMMENT 'Customer account identifier (CUST-0000 format). Joins to RAW.CUSTOMERS.',
    SITE_NAME COMMENT 'Name of the deployment site (facility and city).',
    SITE_TYPE COMMENT 'Site environment category: Manufacturing Floor, Warehouse, Laboratory, Underground, Hazardous Area or Outdoor Industrial.',
    DEPLOYMENT_DATE COMMENT 'Date robots were first deployed at the site.',
    ROBOT_COUNT COMMENT 'Number of robots assigned to the site. Reconciled to the actual count of rows in RAW.ROBOTS.',
    PRIMARY_USE_CASE COMMENT 'Main job the robots perform at the site, for example Autonomous Inspection, Material Handling, Truck Unloading, Security Patrol or Inventory Management.',
    ENVIRONMENT COMMENT 'Operating environment: Indoor, Outdoor, Mixed or Hazardous.',
    STATUS COMMENT 'Site status: Active, Maintenance or Decommissioned.',
    LATITUDE COMMENT 'Site latitude in decimal degrees (approximate city location).',
    LONGITUDE COMMENT 'Site longitude in decimal degrees (approximate city location).';
COMMENT ON TABLE BD_INTELLIGENCE.RAW.FIRMWARE_RELEASES IS 'Firmware release history per robot model (30 releases) with release notes, criticality and affected subsystems. Synthetic demo data.';
ALTER TABLE BD_INTELLIGENCE.RAW.FIRMWARE_RELEASES ALTER
    RELEASE_ID COMMENT 'Unique identifier of the firmware release. Primary key.',
    VERSION COMMENT 'Firmware version number (major.minor.patch).',
    ROBOT_MODEL COMMENT 'Robot platform: Atlas (humanoid), Spot (quadruped) or Stretch (warehouse case handling).',
    RELEASE_DATE COMMENT 'Date the firmware was released.',
    RELEASE_NOTES COMMENT 'Summary of changes in the release.',
    IS_CRITICAL COMMENT 'TRUE if the release is a critical update that should be installed promptly (for example security patches).',
    AFFECTED_COMPONENTS COMMENT 'Robot subsystems changed by the release.';
COMMENT ON TABLE BD_INTELLIGENCE.RAW.INCIDENTS IS 'Operational incidents (about 1,400) such as hardware failures, emergency stops and navigation errors, with severity, downtime, root cause and resolution. Frequency is weighted by the customer profile (at-risk accounts have more). RESOLVED_AT is NULL for open incidents. Synthetic demo data.';
ALTER TABLE BD_INTELLIGENCE.RAW.INCIDENTS ALTER
    INCIDENT_ID COMMENT 'Unique identifier of the incident. Primary key.',
    ROBOT_ID COMMENT 'Robot identifier (BOT-00000 format). Joins to RAW.ROBOTS.',
    DEPLOYMENT_ID COMMENT 'Deployment site where the incident occurred. Joins to RAW.DEPLOYMENTS.',
    INCIDENT_TYPE COMMENT 'Incident category: Hardware Failure, Battery Critical, Sensor Malfunction, Emergency Stop, Environmental Hazard, Communication Loss, Software Error or Navigation Error.',
    SEVERITY COMMENT 'Incident severity: Critical, High, Medium or Low.',
    DESCRIPTION COMMENT 'Narrative description of what happened.',
    REPORTED_AT COMMENT 'Timestamp the incident was reported.',
    RESOLVED_AT COMMENT 'Timestamp the incident was resolved; NULL while still open. Always later than REPORTED_AT.',
    RESOLUTION COMMENT 'Corrective action taken; NULL for open incidents.',
    ROOT_CAUSE COMMENT 'Root cause category: Component wear, Software bug, Calibration drift, Network infrastructure, Power supply fluctuation, Operator error or Environmental conditions.',
    DOWNTIME_MINUTES COMMENT 'Robot downtime caused by the incident in minutes.';
COMMENT ON TABLE BD_INTELLIGENCE.RAW.INTERACTIONS IS 'Customer-facing touchpoints (about 2,500): QBRs, check-in and escalation calls, emails, site visits, trainings and executive briefings, with summary notes, sentiment and next steps. Indexed by the BD_INTERACTION_SEARCH Cortex Search service. Synthetic demo data.';
ALTER TABLE BD_INTELLIGENCE.RAW.INTERACTIONS ALTER
    INTERACTION_ID COMMENT 'Unique identifier of the customer interaction. Primary key.',
    CUSTOMER_ID COMMENT 'Customer account identifier (CUST-0000 format). Joins to RAW.CUSTOMERS.',
    CONTACT_ID COMMENT 'Primary customer contact involved in the interaction.',
    INTERACTION_TYPE COMMENT 'Touchpoint type: QBR, Check-in Call, Escalation Call, Email, Site Visit, Training Session or Executive Briefing.',
    INTERACTION_DATE COMMENT 'Date of the interaction.',
    OWNER COMMENT 'Boston Dynamics employee (CSM or account executive) who led the interaction.',
    SUBJECT COMMENT 'Interaction subject line.',
    SUMMARY COMMENT 'Narrative notes from the interaction. Searchable via BD_INTERACTION_SEARCH.',
    SENTIMENT COMMENT 'Overall customer sentiment in the interaction: Positive, Neutral or Negative.',
    NEXT_STEPS COMMENT 'Agreed follow-up action.';
COMMENT ON TABLE BD_INTELLIGENCE.RAW.INVOICES IS 'Billing and collections history (about 2,000 invoices): invoice and due dates, amount, payment date, payment status and days late. Late payment is more common for at-risk accounts. Synthetic demo data.';
ALTER TABLE BD_INTELLIGENCE.RAW.INVOICES ALTER
    INVOICE_ID COMMENT 'Unique identifier of the invoice. Primary key.',
    CONTRACT_ID COMMENT 'Contract being billed. Joins to RAW.CONTRACTS.',
    CUSTOMER_ID COMMENT 'Customer account identifier (CUST-0000 format). Joins to RAW.CUSTOMERS.',
    INVOICE_DATE COMMENT 'Date the invoice was issued.',
    DUE_DATE COMMENT 'Payment due date.',
    AMOUNT_USD COMMENT 'Invoice amount in US dollars.',
    PAID_DATE COMMENT 'Date payment was received; NULL if unpaid.',
    PAYMENT_STATUS COMMENT 'Payment status: Paid (on time), Paid Late, Open (not yet due) or Overdue (past due and unpaid).',
    DAYS_LATE COMMENT 'Days payment was received after the due date (0 if on time, or days overdue so far if unpaid).';
COMMENT ON TABLE BD_INTELLIGENCE.RAW.KNOWLEDGE_BASE IS 'Technical documentation and Customer Success playbooks (25 articles) indexed by the BD_KNOWLEDGE_SEARCH Cortex Search service: product specs, procedures, troubleshooting, safety and account-management guidance. Synthetic demo data.';
ALTER TABLE BD_INTELLIGENCE.RAW.KNOWLEDGE_BASE ALTER
    ARTICLE_ID COMMENT 'Unique identifier of the knowledge base article. Primary key.',
    TITLE COMMENT 'Article title.',
    CATEGORY COMMENT 'Article category: Product Specifications, Technical Procedures, Maintenance, Troubleshooting, Safety & Compliance, Operations or Customer Success.',
    SUBCATEGORY COMMENT 'Article subcategory within the category.',
    CONTENT COMMENT 'Full article text. Searchable column of BD_KNOWLEDGE_SEARCH.',
    ROBOT_MODEL COMMENT 'Robot model the article applies to: Atlas, Spot, Stretch or All Models.',
    TAGS COMMENT 'Comma-separated keywords for the article.',
    AUTHOR COMMENT 'Author or owning team of the article.',
    CREATED_AT COMMENT 'Timestamp the record was created.',
    UPDATED_AT COMMENT 'Timestamp the record was last updated.';
COMMENT ON TABLE BD_INTELLIGENCE.RAW.MAINTENANCE_RECORDS IS 'Service history (6,000 events): maintenance type, technician, cost, duration, parts replaced and outcome. Each record references a component that belongs to the serviced robot. Synthetic demo data.';
ALTER TABLE BD_INTELLIGENCE.RAW.MAINTENANCE_RECORDS ALTER
    MAINTENANCE_ID COMMENT 'Unique identifier of the maintenance event. Primary key.',
    ROBOT_ID COMMENT 'Robot identifier (BOT-00000 format). Joins to RAW.ROBOTS.',
    COMPONENT_ID COMMENT 'Component that was serviced. Always belongs to the same robot as ROBOT_ID. Joins to RAW.COMPONENTS.',
    MAINTENANCE_TYPE COMMENT 'Kind of maintenance: Preventive, Corrective, Predictive, Calibration or Firmware Update.',
    DESCRIPTION COMMENT 'Technician''s description of the work performed.',
    PERFORMED_BY COMMENT 'Field technician who performed the work.',
    PERFORMED_AT COMMENT 'Timestamp the maintenance was performed.',
    DURATION_MINUTES COMMENT 'Labour time for the event in minutes (15-480).',
    COST_USD COMMENT 'Total cost of the maintenance event in US dollars (parts plus labour).',
    PARTS_REPLACED COMMENT 'Parts replaced during the event; NULL when no parts were replaced.',
    OUTCOME COMMENT 'Result of the work: Resolved or Monitoring (follow-up needed).',
    NEXT_SCHEDULED COMMENT 'Date of the next scheduled maintenance for the robot.';
COMMENT ON TABLE BD_INTELLIGENCE.RAW.OPPORTUNITIES IS 'Sales pipeline (about 350 opportunities): renewals, expansions, upsells, new sites and services, with stage, amount, probability, dates, outcome and loss reason. Synthetic demo data.';
ALTER TABLE BD_INTELLIGENCE.RAW.OPPORTUNITIES ALTER
    OPPORTUNITY_ID COMMENT 'Sales opportunity identifier. Primary key of RAW.OPPORTUNITIES.',
    CUSTOMER_ID COMMENT 'Customer account identifier (CUST-0000 format). Joins to RAW.CUSTOMERS.',
    OPPORTUNITY_NAME COMMENT 'Opportunity name: customer, opportunity type and product line.',
    OPPORTUNITY_TYPE COMMENT 'Opportunity type: Renewal, Expansion, Upsell, New Site or Services.',
    PRODUCT_LINE COMMENT 'Robot product line covered: Atlas, Spot or Stretch.',
    STAGE COMMENT 'Sales stage: Discovery, Qualification, Proposal, Negotiation, Commit, Closed Won or Closed Lost.',
    AMOUNT_USD COMMENT 'Opportunity value in US dollars.',
    PROBABILITY_PCT COMMENT 'Win probability in percent for the current stage (0-100; 100 for Closed Won, 0 for Closed Lost).',
    CREATED_DATE COMMENT 'Date the opportunity was created.',
    CLOSE_DATE COMMENT 'Expected close date for open opportunities, actual close date for closed ones.',
    OWNER COMMENT 'Account executive who owns the opportunity.',
    IS_CLOSED COMMENT 'TRUE if the opportunity is Closed Won or Closed Lost.',
    IS_WON COMMENT 'TRUE if the opportunity is Closed Won.',
    LOSS_REASON COMMENT 'Reason the opportunity was lost: Budget cuts, Insufficient ROI, Moved to competitor, Project cancelled or Unresolved reliability issues. NULL unless Closed Lost.';
COMMENT ON TABLE BD_INTELLIGENCE.RAW.PRODUCT_USAGE_DAILY IS 'Daily product adoption per customer (36,500 rows: 365 days per customer, ending at the churn date for churned customers): active robots, operating hours, missions, autonomy rate, features used and app logins. Primary key is CUSTOMER_ID + USAGE_DATE. Synthetic demo data.';
ALTER TABLE BD_INTELLIGENCE.RAW.PRODUCT_USAGE_DAILY ALTER
    CUSTOMER_ID COMMENT 'Customer account identifier (CUST-0000 format). Joins to RAW.CUSTOMERS.',
    USAGE_DATE COMMENT 'Calendar day the usage was recorded.',
    ACTIVE_ROBOTS COMMENT 'Number of the customer''s robots that operated on the day.',
    OPERATING_HOURS COMMENT 'Total robot operating hours across the customer''s fleet for the day.',
    MISSIONS_COMPLETED COMMENT 'Number of autonomous missions completed across the fleet for the day.',
    AUTONOMY_PCT COMMENT 'Percentage of operating time the robots ran autonomously rather than under remote control.',
    FEATURES_USED COMMENT 'Number of distinct software features used during the day (4-12).',
    APP_LOGINS COMMENT 'Number of logins to the fleet management app for the day.';
COMMENT ON TABLE BD_INTELLIGENCE.RAW.ROBOTS IS 'Robot fleet inventory: one row per Atlas (humanoid), Spot (quadruped) or Stretch (warehouse) unit (600 robots), with model, serial, firmware, status and the deployment site it is assigned to. Synthetic demo data.';
ALTER TABLE BD_INTELLIGENCE.RAW.ROBOTS ALTER
    ROBOT_ID COMMENT 'Unique robot identifier (BOT-00000 format). Primary key.',
    ROBOT_NAME COMMENT 'Human-readable robot name, model plus sequence (for example Spot-019).',
    ROBOT_MODEL COMMENT 'Robot platform: Atlas (humanoid), Spot (quadruped) or Stretch (warehouse case handling).',
    SERIAL_NUMBER COMMENT 'Manufacturer serial number (BD-...).',
    MANUFACTURE_DATE COMMENT 'Date the robot was manufactured.',
    FIRMWARE_VERSION COMMENT 'Firmware version currently installed on the robot (major.minor.patch).',
    STATUS COMMENT 'Robot status: Active, Idle, Maintenance or Decommissioned.',
    DEPLOYMENT_ID COMMENT 'Deployment site the robot is currently assigned to. Joins to RAW.DEPLOYMENTS.',
    CREATED_AT COMMENT 'Timestamp the record was created.',
    UPDATED_AT COMMENT 'Timestamp the record was last updated.';
COMMENT ON TABLE BD_INTELLIGENCE.RAW.ROBOT_TELEMETRY IS 'Sensor readings streamed from robots (150,000 rows, April 2025 to October 2026): battery, temperatures, vibration, joint load, speed, orientation, position, operating mode and error codes. Synthetic demo data.';
ALTER TABLE BD_INTELLIGENCE.RAW.ROBOT_TELEMETRY ALTER
    TELEMETRY_ID COMMENT 'Unique identifier of the telemetry reading. Primary key.',
    ROBOT_ID COMMENT 'Robot identifier (BOT-00000 format). Joins to RAW.ROBOTS.',
    TIMESTAMP COMMENT 'Time the reading was captured (UTC, no time zone).',
    BATTERY_LEVEL COMMENT 'Battery state of charge in percent (5-100).',
    CPU_TEMPERATURE_C COMMENT 'Onboard compute temperature in degrees Celsius.',
    MOTOR_TEMPERATURE_C COMMENT 'Drive motor temperature in degrees Celsius (observed range 30-112).',
    VIBRATION_MM_S COMMENT 'Vibration velocity in mm/s (observed range 0.1-15); higher values indicate mechanical wear.',
    JOINT_LOAD_PERCENT COMMENT 'Peak joint load as a percentage of rated capacity.',
    SPEED_M_S COMMENT 'Ground speed in metres per second.',
    ORIENTATION_ROLL COMMENT 'Body roll angle in degrees.',
    ORIENTATION_PITCH COMMENT 'Body pitch angle in degrees.',
    ORIENTATION_YAW COMMENT 'Body heading (yaw) in degrees (-180 to 180).',
    LOCATION_X COMMENT 'X position in metres in the site''s local coordinate frame.',
    LOCATION_Y COMMENT 'Y position in metres in the site''s local coordinate frame.',
    LOCATION_Z COMMENT 'Height in metres in the site''s local coordinate frame.',
    OPERATIONAL_MODE COMMENT 'Operating mode at the time of the reading: Autonomous Navigation, Remote Control, Material Handling, Inspection Mode, Idle Standby or Charging.',
    ERROR_CODE COMMENT 'Fault code raised at the time of the reading (ERR-###); NULL when there was no error (about 95% of readings).';
COMMENT ON TABLE BD_INTELLIGENCE.RAW.SUPPORT_TICKETS IS 'Customer support cases (about 2,800) with category, priority, channel, status, resolution time, SLA attainment and post-resolution CSAT. Indexed by the BD_SUPPORT_TICKET_SEARCH Cortex Search service. Synthetic demo data.';
ALTER TABLE BD_INTELLIGENCE.RAW.SUPPORT_TICKETS ALTER
    TICKET_ID COMMENT 'Support ticket identifier. Primary key of RAW.SUPPORT_TICKETS.',
    CUSTOMER_ID COMMENT 'Customer account identifier (CUST-0000 format). Joins to RAW.CUSTOMERS.',
    CONTACT_ID COMMENT 'Customer contact who raised the ticket.',
    ROBOT_ID COMMENT 'Robot the ticket relates to. Reserved for future use: currently NULL on every ticket, so tickets link to customers, not individual robots.',
    CATEGORY COMMENT 'Ticket category: Hardware, Software, Navigation, Battery, Connectivity, Integration, Training or Billing.',
    PRIORITY COMMENT 'Ticket priority: Critical, High, Medium or Low. Drives the SLA target.',
    CHANNEL COMMENT 'Channel the ticket was raised through: Portal, Email, Phone or Field Engineer.',
    SUBJECT COMMENT 'Short ticket subject line.',
    DESCRIPTION COMMENT 'Ticket description written by the customer or support engineer. Searchable via BD_SUPPORT_TICKET_SEARCH. Does not include the resolution.',
    STATUS COMMENT 'Ticket status: Open or Closed.',
    OPENED_AT COMMENT 'Timestamp the ticket was opened.',
    CLOSED_AT COMMENT 'Timestamp the ticket was closed; NULL while open.',
    RESOLUTION_HOURS COMMENT 'Hours from open to close; NULL while open.',
    SLA_MET COMMENT 'TRUE if the ticket was resolved within the SLA for its priority and the customer''s support tier.',
    CSAT_SCORE COMMENT 'Customer satisfaction rating for the ticket, 1 (very dissatisfied) to 5 (very satisfied); NULL if not rated.',
    ASSIGNED_TO COMMENT 'Support engineer who owns the ticket.';
COMMENT ON TABLE BD_INTELLIGENCE.RAW.SURVEYS IS 'NPS (0-10) and CSAT (1-5) survey responses (1,200) with category and verbatim comment. Verbatims are indexed by the BD_CUSTOMER_FEEDBACK_SEARCH Cortex Search service. Synthetic demo data.';
ALTER TABLE BD_INTELLIGENCE.RAW.SURVEYS ALTER
    SURVEY_ID COMMENT 'Survey response identifier. Primary key of RAW.SURVEYS.',
    CUSTOMER_ID COMMENT 'Customer account identifier (CUST-0000 format). Joins to RAW.CUSTOMERS.',
    CONTACT_ID COMMENT 'Customer contact who answered the survey.',
    SURVEY_TYPE COMMENT 'Survey type: NPS (likelihood to recommend, 0-10) or CSAT (satisfaction, 1-5).',
    SCORE COMMENT 'Survey score: 0-10 for NPS, 1-5 for CSAT.',
    NPS_CATEGORY COMMENT 'Score category. NPS: Promoter (9-10), Passive (7-8), Detractor (0-6). CSAT: Satisfied (4-5), Neutral (3), Dissatisfied (1-2).',
    VERBATIM COMMENT 'Free-text comment left by the respondent. Searchable via BD_CUSTOMER_FEEDBACK_SEARCH.',
    RESPONSE_DATE COMMENT 'Date the survey was answered.';
-- @comments-end
