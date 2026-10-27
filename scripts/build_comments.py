"""
Generate table, view and column descriptions for BD_INTELLIGENCE.

Descriptions live in this file (single source of truth). The script reads the
live column inventory from INFORMATION_SCHEMA, fails if any column lacks a
description, and rewrites two generated blocks:

  sql/setup/02_create_tables.sql  - COMMENT ON TABLE / ALTER TABLE ... COMMENT
                                    for every RAW table (between @comments markers)
  sql/views/04_create_views.sql   - a commented column list on every CREATE VIEW
                                    (between @cols markers) and comments for
                                    ANALYTICS.CUSTOMER_ML_SCORES

Usage:
    python3 scripts/build_comments.py --connection AWS161            # regenerate SQL
    python3 scripts/build_comments.py --connection AWS161 --apply     # also apply table comments live
"""
import argparse
import pathlib
import re

import snowflake.connector

ROOT = pathlib.Path(__file__).resolve().parent.parent
TABLES_SQL = ROOT / "sql/setup/02_create_tables.sql"
VIEWS_SQL = ROOT / "sql/views/04_create_views.sql"
SYN = "Synthetic demo data."

# ---------------------------------------------------------------------------
# Object descriptions
# ---------------------------------------------------------------------------
OBJECTS = {
    # RAW tables
    "RAW.CUSTOMERS": "One row per Boston Dynamics customer account (100 accounts). Firmographics, segment, account team, contract window and lifecycle stage. Lifecycle stage drives the correlated signals in every Customer 360 table (healthy, expanding, at risk, churned). " + SYN,
    "RAW.DEPLOYMENTS": "One row per customer deployment site (200 sites). Each site belongs to one customer and hosts one or more robots. ROBOT_COUNT is reconciled to the number of rows in ROBOTS. " + SYN,
    "RAW.ROBOTS": "Robot fleet inventory: one row per Atlas (humanoid), Spot (quadruped) or Stretch (warehouse) unit (600 robots), with model, serial, firmware, status and the deployment site it is assigned to. " + SYN,
    "RAW.COMPONENTS": "Major components installed on each robot (3,000 rows, about 5 per robot): type, install date, rated lifespan, runtime, condition status and the remaining useful life estimated at the last inspection. Status and RUL derive from a hidden wear index. " + SYN,
    "RAW.ROBOT_TELEMETRY": "Sensor readings streamed from robots (150,000 rows, April 2025 to October 2026): battery, temperatures, vibration, joint load, speed, orientation, position, operating mode and error codes. " + SYN,
    "RAW.MAINTENANCE_RECORDS": "Service history (6,000 events): maintenance type, technician, cost, duration, parts replaced and outcome. Each record references a component that belongs to the serviced robot. " + SYN,
    "RAW.INCIDENTS": "Operational incidents (about 1,400) such as hardware failures, emergency stops and navigation errors, with severity, downtime, root cause and resolution. Frequency is weighted by the customer profile (at-risk accounts have more). RESOLVED_AT is NULL for open incidents. " + SYN,
    "RAW.KNOWLEDGE_BASE": "Technical documentation and Customer Success playbooks (25 articles) indexed by the BD_KNOWLEDGE_SEARCH Cortex Search service: product specs, procedures, troubleshooting, safety and account-management guidance. " + SYN,
    "RAW.FIRMWARE_RELEASES": "Firmware release history per robot model (30 releases) with release notes, criticality and affected subsystems. " + SYN,
    "RAW.CONTACTS": "Customer stakeholders (400 rows, 4 per account) with title, buying role, contact details and primary-contact flag. Names repeat across accounts. Emails and phone numbers are fabricated. " + SYN,
    "RAW.CONTRACTS": "Commercial agreements (219 rows): annual terms of RaaS subscriptions, purchase + support and leases, plus separate Expansion contracts. Each row has ARR, total contract value, robot quantity and status (Active, Renewed, Churned). " + SYN,
    "RAW.INVOICES": "Billing and collections history (about 2,000 invoices): invoice and due dates, amount, payment date, payment status and days late. Late payment is more common for at-risk accounts. " + SYN,
    "RAW.SUPPORT_TICKETS": "Customer support cases (about 2,800) with category, priority, channel, status, resolution time, SLA attainment and post-resolution CSAT. Indexed by the BD_SUPPORT_TICKET_SEARCH Cortex Search service. " + SYN,
    "RAW.SURVEYS": "NPS (0-10) and CSAT (1-5) survey responses (1,200) with category and verbatim comment. Verbatims are indexed by the BD_CUSTOMER_FEEDBACK_SEARCH Cortex Search service. " + SYN,
    "RAW.PRODUCT_USAGE_DAILY": "Daily product adoption per customer (36,500 rows: 365 days per customer, ending at the churn date for churned customers): active robots, operating hours, missions, autonomy rate, features used and app logins. Primary key is CUSTOMER_ID + USAGE_DATE. " + SYN,
    "RAW.OPPORTUNITIES": "Sales pipeline (about 350 opportunities): renewals, expansions, upsells, new sites and services, with stage, amount, probability, dates, outcome and loss reason. " + SYN,
    "RAW.INTERACTIONS": "Customer-facing touchpoints (about 2,500): QBRs, check-in and escalation calls, emails, site visits, trainings and executive briefings, with summary notes, sentiment and next steps. Indexed by the BD_INTERACTION_SEARCH Cortex Search service. " + SYN,
    # ANALYTICS views
    "ANALYTICS.FLEET_OVERVIEW": "One row per robot with its deployment site, customer and a roll-up of component condition. Source for the BD_FLEET_OPERATIONS_SV semantic view.",
    "ANALYTICS.TELEMETRY_DAILY_SUMMARY": "Telemetry aggregated to one row per robot per day: reading count, average/min/max of battery, temperatures, vibration, joint load and speed, plus error counts. Source for BD_TELEMETRY_ANALYTICS_SV.",
    "ANALYTICS.MAINTENANCE_ANALYSIS": "Maintenance aggregated per robot and maintenance type over all history: event count, total/average cost and duration, first/last service date and parts replacements. Source for BD_MAINTENANCE_INTELLIGENCE_SV.",
    "ANALYTICS.MAINTENANCE_MONTHLY_TREND": "Maintenance aggregated per month, robot model, maintenance type, site, customer and technician, for time-series analysis of cost, volume and duration. Source for BD_MAINTENANCE_TRENDS_SV.",
    "ANALYTICS.INCIDENT_DASHBOARD": "Incidents aggregated per robot, incident type and severity: count, downtime, resolved vs unresolved and first/last occurrence. Source for BD_INCIDENT_ANALYSIS_SV.",
    "ANALYTICS.COMPONENT_HEALTH": "One row per component with age, lifecycle consumption, inspection-based remaining useful life and a rule-based risk level. Used by the RUL agent tool and the Robot RUL Streamlit dashboard.",
    "ANALYTICS.CUSTOMER_FLEET_SUMMARY": "One row per customer summarising deployments, robot counts by status and model, total maintenance cost, incidents and downtime over all history.",
    "ANALYTICS.ROBOT_MODEL_PERFORMANCE": "One row per robot model (Atlas, Spot, Stretch) comparing fleet size, age, average telemetry, incident rate and maintenance cost per robot.",
    "ANALYTICS.DEPLOYMENT_PERFORMANCE": "One row per deployment site with customer, robot counts, total incidents, downtime and maintenance cost.",
    "ANALYTICS.CUSTOMER_360": "Customer 360: one row per customer combining firmographics, contracts and ARR, renewals, fleet, incidents, support, NPS, usage, billing, pipeline, interaction sentiment and ML scores. Rolling windows (30/90/180/365 days) end at AS_OF_DATE (today, or the churn date for churned customers). Source for BD_CUSTOMER_360_SV and the Customer 360 agent UDFs.",
    "ANALYTICS.CUSTOMER_ML_FEATURES": "Point-in-time training and scoring features for the customer ML models. Grain is CUSTOMER_ID + SNAPSHOT_K. SNAPSHOT_K = 0 is the scoring row at the as-of date; 1-9 step back 30 days each and carry 180-day forward churn and expansion labels (NULL until the outcome window has elapsed). Used by notebooks/07_ml_models.",
    "ANALYTICS.CUSTOMER_REVENUE_MONTHLY": "Billing and collections per customer per invoice month: invoiced, collected, paid late, overdue and open amounts, with late-invoice counts. Source for BD_REVENUE_SV.",
    "ANALYTICS.SUPPORT_TICKET_ANALYSIS": "One row per support ticket enriched with customer and robot context, for volume, SLA, resolution-time and CSAT analysis. Source for BD_SUPPORT_SV.",
    "ANALYTICS.CUSTOMER_USAGE_TREND": "Product adoption per customer per month: average active robots, utilisation against fleet size, operating hours, missions, autonomy, features used and logins. Source for BD_PRODUCT_USAGE_SV.",
    "ANALYTICS.SALES_PIPELINE": "One row per opportunity enriched with customer context, weighted amount, close quarter and sales-cycle length. Source for BD_PIPELINE_SV.",
    "ANALYTICS.CUSTOMER_SURVEY_RESULTS": "One row per NPS or CSAT response enriched with customer and respondent context and the response month. Joined into BD_CUSTOMER_360_SV for survey analysis.",
    "ANALYTICS.CUSTOMER_ML_SCORES": "Latest batch scores from the Model Registry models BD_CHURN_RISK, BD_CUSTOMER_HEALTH_SCORE and BD_EXPANSION_PROPENSITY: one row per customer. Written by notebooks/07_ml_models and joined into CUSTOMER_360. Metrics are optimistic because the synthetic signals are clean.",
}

# ---------------------------------------------------------------------------
# Column descriptions. Keys are COLUMN_NAME (shared meaning) or
# TABLE.COLUMN_NAME (table-specific override, checked first).
# ---------------------------------------------------------------------------
C = {
    # Identifiers
    "CUSTOMER_ID": "Customer account identifier (CUST-0000 format). Joins to RAW.CUSTOMERS.",
    "DEPLOYMENT_ID": "Deployment site identifier (DEP-0000 format). Joins to RAW.DEPLOYMENTS.",
    "ROBOT_ID": "Robot identifier (BOT-00000 format). Joins to RAW.ROBOTS.",
    "COMPONENT_ID": "Component identifier (COMP-00000 format). Joins to RAW.COMPONENTS.",
    "CONTACT_ID": "Customer contact identifier (CON-00000 format). Joins to RAW.CONTACTS.",
    "CONTRACT_ID": "Contract identifier (CTR-00000 format). Joins to RAW.CONTRACTS.",
    "TELEMETRY_ID": "Unique identifier of the telemetry reading. Primary key.",
    "MAINTENANCE_ID": "Unique identifier of the maintenance event. Primary key.",
    "INCIDENT_ID": "Unique identifier of the incident. Primary key.",
    "ARTICLE_ID": "Unique identifier of the knowledge base article. Primary key.",
    "RELEASE_ID": "Unique identifier of the firmware release. Primary key.",
    "INVOICE_ID": "Unique identifier of the invoice. Primary key.",
    "TICKET_ID": "Support ticket identifier. Primary key of RAW.SUPPORT_TICKETS.",
    "SURVEY_ID": "Survey response identifier. Primary key of RAW.SURVEYS.",
    "OPPORTUNITY_ID": "Sales opportunity identifier. Primary key of RAW.OPPORTUNITIES.",
    "INTERACTION_ID": "Unique identifier of the customer interaction. Primary key.",
    "CUSTOMERS.CUSTOMER_ID": "Unique customer account identifier (CUST-0000 format). Primary key.",
    "DEPLOYMENTS.DEPLOYMENT_ID": "Unique deployment site identifier (DEP-0000 format). Primary key.",
    "ROBOTS.ROBOT_ID": "Unique robot identifier (BOT-00000 format). Primary key.",
    "COMPONENTS.COMPONENT_ID": "Unique component identifier (COMP-00000 format). Primary key.",
    "CONTACTS.CONTACT_ID": "Unique contact identifier (CON-00000 format). Primary key.",
    "CONTRACTS.CONTRACT_ID": "Unique contract identifier (CTR-00000 format). Primary key.",
    "ROBOTS.DEPLOYMENT_ID": "Deployment site the robot is currently assigned to. Joins to RAW.DEPLOYMENTS.",
    "INCIDENTS.DEPLOYMENT_ID": "Deployment site where the incident occurred. Joins to RAW.DEPLOYMENTS.",
    "MAINTENANCE_RECORDS.COMPONENT_ID": "Component that was serviced. Always belongs to the same robot as ROBOT_ID. Joins to RAW.COMPONENTS.",
    "SUPPORT_TICKETS.ROBOT_ID": "Robot the ticket relates to. Reserved for future use: currently NULL on every ticket, so tickets link to customers, not individual robots.",
    "SUPPORT_TICKET_ANALYSIS.ROBOT_ID": "Robot the ticket relates to. Currently NULL on every ticket (not populated in the source data).",
    "SUPPORT_TICKET_ANALYSIS.ROBOT_MODEL": "Model of the robot the ticket relates to. Currently NULL because ROBOT_ID is not populated on tickets.",
    "SUPPORT_TICKETS.CONTACT_ID": "Customer contact who raised the ticket.",
    "SURVEYS.CONTACT_ID": "Customer contact who answered the survey.",
    "INTERACTIONS.CONTACT_ID": "Primary customer contact involved in the interaction.",
    "INVOICES.CONTRACT_ID": "Contract being billed. Joins to RAW.CONTRACTS.",

    # Customer attributes
    "CUSTOMER_NAME": "Customer company name (for example Siemens Energy, Tesla Gigafactory).",
    "INDUSTRY": "Customer industry: Automotive Manufacturing, Logistics & Warehousing, Energy & Utilities, Aerospace & Defense, Industrial Manufacturing or Mining & Resources.",
    "CUSTOMER_INDUSTRY": "Industry of the customer that owns the site (same values as CUSTOMERS.INDUSTRY).",
    "COMPANY_SIZE": "Legacy size band: Enterprise, Large or Mid-Market. Prefer SEGMENT for Customer 360 analysis.",
    "REGION": "Customer headquarters region: North America, Europe, Asia Pacific, South America or Middle East & Africa.",
    "CUSTOMER_REGION": "Headquarters region of the customer that owns the site.",
    "COUNTRY": "Country of the customer headquarters.",
    "HQ_CITY": "City of the customer headquarters.",
    "SEGMENT": "Go-to-market segment based on annual revenue: Strategic (largest), Enterprise or Commercial.",
    "ANNUAL_REVENUE_USD": "Customer company annual revenue in US dollars (the customer's own revenue, not spend with Boston Dynamics). Log-uniform between about $2B and $386B.",
    "EMPLOYEE_COUNT": "Approximate number of employees at the customer company.",
    "SUPPORT_TIER": "Purchased support entitlement: Platinum, Gold, Silver or Bronze. Higher tiers have tighter SLAs.",
    "ACCOUNT_MANAGER": "Boston Dynamics account executive who owns the commercial relationship.",
    "CSM_NAME": "Customer Success Manager assigned to the account.",
    "LIFECYCLE_STAGE": "Account lifecycle stage: Onboarding, Adopting, Mature, Renewal Due or Churned. Churned accounts have no active contract.",
    "CUSTOMER_SINCE": "Date the customer signed its first contract with Boston Dynamics.",
    "CONTRACT_START_DATE": "Start date of the customer's current (or final, if churned) contract term.",
    "CONTRACT_END_DATE": "End date of the current contract term, i.e. the next renewal date. For churned customers, the churn date.",

    # Deployments
    "SITE_NAME": "Name of the deployment site (facility and city).",
    "SITE_TYPE": "Site environment category: Manufacturing Floor, Warehouse, Laboratory, Underground, Hazardous Area or Outdoor Industrial.",
    "DEPLOYMENT_DATE": "Date robots were first deployed at the site.",
    "DEPLOYMENTS.ROBOT_COUNT": "Number of robots assigned to the site. Reconciled to the actual count of rows in RAW.ROBOTS.",
    "PRIMARY_USE_CASE": "Main job the robots perform at the site, for example Autonomous Inspection, Material Handling, Truck Unloading, Security Patrol or Inventory Management.",
    "ENVIRONMENT": "Operating environment: Indoor, Outdoor, Mixed or Hazardous.",
    "DEPLOYMENT_ENVIRONMENT": "Operating environment of the site: Indoor, Outdoor, Mixed or Hazardous.",
    "DEPLOYMENTS.STATUS": "Site status: Active, Maintenance or Decommissioned.",
    "LATITUDE": "Site latitude in decimal degrees (approximate city location).",
    "LONGITUDE": "Site longitude in decimal degrees (approximate city location).",

    # Robots
    "ROBOT_NAME": "Human-readable robot name, model plus sequence (for example Spot-019).",
    "ROBOT_MODEL": "Robot platform: Atlas (humanoid), Spot (quadruped) or Stretch (warehouse case handling).",
    "SERIAL_NUMBER": "Manufacturer serial number (BD-...).",
    "MANUFACTURE_DATE": "Date the robot was manufactured.",
    "FIRMWARE_VERSION": "Firmware version currently installed on the robot (major.minor.patch).",
    "ROBOTS.STATUS": "Robot status: Active, Idle, Maintenance or Decommissioned.",
    "ROBOT_STATUS": "Robot status: Active, Idle, Maintenance or Decommissioned.",
    "CREATED_AT": "Timestamp the record was created.",
    "UPDATED_AT": "Timestamp the record was last updated.",

    # Components
    "COMPONENT_TYPE": "Component category: Motor, Battery, Sensor, LiDAR, Camera, Joint Actuator, Hydraulic Pump, Gripper, Controller Board or Communication Module.",
    "COMPONENT_NAME": "Specific component name (for example Knee Motor, Precision Gripper).",
    "INSTALL_DATE": "Date the component was installed on the robot.",
    "EXPECTED_LIFESPAN_DAYS": "Rated design lifespan of the component in days (365-3,991).",
    "CURRENT_RUNTIME_HOURS": "Cumulative operating hours on the component since installation.",
    "COMPONENTS.STATUS": "Condition at last inspection: Operational, Degraded, Needs Replacement or Failed.",
    "COMPONENT_STATUS": "Condition at last inspection: Operational, Degraded, Needs Replacement or Failed.",
    "LAST_INSPECTION_DATE": "Date of the most recent technician inspection of the component.",
    "INSPECTION_RUL_DAYS": "Remaining useful life in days estimated at the last inspection from observed wear (0 = worn out). Target of the BD_REMAINING_USEFUL_LIFE model. Unlike EXPECTED_LIFESPAN_DAYS minus age, it reflects actual condition.",
    "DAYS_SINCE_INSTALL": "Days since the component was installed (CURRENT_DATE minus INSTALL_DATE).",
    "LIFECYCLE_PERCENT_USED": "Age as a percentage of rated lifespan (DAYS_SINCE_INSTALL / EXPECTED_LIFESPAN_DAYS x 100). Above 100 means the component is past its rated life.",
    "DAYS_SINCE_INSPECTION": "Days since the last inspection.",
    "RISK_LEVEL": "Rule-based replacement risk: Critical (Failed), High (Needs Replacement or more than 90% of rated life used), Medium (Degraded or more than 75% used), otherwise Low.",

    # Telemetry
    "TIMESTAMP": "Time the reading was captured (UTC, no time zone).",
    "BATTERY_LEVEL": "Battery state of charge in percent (5-100).",
    "CPU_TEMPERATURE_C": "Onboard compute temperature in degrees Celsius.",
    "MOTOR_TEMPERATURE_C": "Drive motor temperature in degrees Celsius (observed range 30-112).",
    "VIBRATION_MM_S": "Vibration velocity in mm/s (observed range 0.1-15); higher values indicate mechanical wear.",
    "JOINT_LOAD_PERCENT": "Peak joint load as a percentage of rated capacity.",
    "SPEED_M_S": "Ground speed in metres per second.",
    "ORIENTATION_ROLL": "Body roll angle in degrees.",
    "ORIENTATION_PITCH": "Body pitch angle in degrees.",
    "ORIENTATION_YAW": "Body heading (yaw) in degrees (-180 to 180).",
    "LOCATION_X": "X position in metres in the site's local coordinate frame.",
    "LOCATION_Y": "Y position in metres in the site's local coordinate frame.",
    "LOCATION_Z": "Height in metres in the site's local coordinate frame.",
    "OPERATIONAL_MODE": "Operating mode at the time of the reading: Autonomous Navigation, Remote Control, Material Handling, Inspection Mode, Idle Standby or Charging.",
    "ERROR_CODE": "Fault code raised at the time of the reading (ERR-###); NULL when there was no error (about 95% of readings).",

    # Maintenance
    "MAINTENANCE_TYPE": "Kind of maintenance: Preventive, Corrective, Predictive, Calibration or Firmware Update.",
    "MAINTENANCE_RECORDS.DESCRIPTION": "Technician's description of the work performed.",
    "PERFORMED_BY": "Field technician who performed the work.",
    "TECHNICIAN": "Field technician who performed the work.",
    "PERFORMED_AT": "Timestamp the maintenance was performed.",
    "MAINTENANCE_RECORDS.DURATION_MINUTES": "Labour time for the event in minutes (15-480).",
    "COST_USD": "Total cost of the maintenance event in US dollars (parts plus labour).",
    "PARTS_REPLACED": "Parts replaced during the event; NULL when no parts were replaced.",
    "OUTCOME": "Result of the work: Resolved or Monitoring (follow-up needed).",
    "NEXT_SCHEDULED": "Date of the next scheduled maintenance for the robot.",

    # Incidents
    "INCIDENT_TYPE": "Incident category: Hardware Failure, Battery Critical, Sensor Malfunction, Emergency Stop, Environmental Hazard, Communication Loss, Software Error or Navigation Error.",
    "SEVERITY": "Incident severity: Critical, High, Medium or Low.",
    "INCIDENTS.DESCRIPTION": "Narrative description of what happened.",
    "REPORTED_AT": "Timestamp the incident was reported.",
    "RESOLVED_AT": "Timestamp the incident was resolved; NULL while still open. Always later than REPORTED_AT.",
    "RESOLUTION": "Corrective action taken; NULL for open incidents.",
    "ROOT_CAUSE": "Root cause category: Component wear, Software bug, Calibration drift, Network infrastructure, Power supply fluctuation, Operator error or Environmental conditions.",
    "DOWNTIME_MINUTES": "Robot downtime caused by the incident in minutes.",

    # Knowledge base / firmware
    "KNOWLEDGE_BASE.TITLE": "Article title.",
    "KNOWLEDGE_BASE.CATEGORY": "Article category: Product Specifications, Technical Procedures, Maintenance, Troubleshooting, Safety & Compliance, Operations or Customer Success.",
    "SUBCATEGORY": "Article subcategory within the category.",
    "CONTENT": "Full article text. Searchable column of BD_KNOWLEDGE_SEARCH.",
    "KNOWLEDGE_BASE.ROBOT_MODEL": "Robot model the article applies to: Atlas, Spot, Stretch or All Models.",
    "TAGS": "Comma-separated keywords for the article.",
    "AUTHOR": "Author or owning team of the article.",
    "VERSION": "Firmware version number (major.minor.patch).",
    "RELEASE_DATE": "Date the firmware was released.",
    "RELEASE_NOTES": "Summary of changes in the release.",
    "IS_CRITICAL": "TRUE if the release is a critical update that should be installed promptly (for example security patches).",
    "AFFECTED_COMPONENTS": "Robot subsystems changed by the release.",

    # Contacts
    "FULL_NAME": "Contact's full name. Names repeat across accounts in the synthetic data.",
    "CONTACTS.TITLE": "Contact's job title.",
    "CONTACT_ROLE": "Buying-group role: Champion, Economic Buyer, Technical User or Procurement.",
    "EMAIL": "Contact email address (fabricated).",
    "PHONE": "Contact phone number (fabricated, +1-555 numbers).",
    "IS_PRIMARY": "TRUE for the account's primary contact.",
    "CONTACT_NAME": "Full name of the contact who answered the survey.",

    # Contracts
    "CONTRACT_TYPE": "Commercial model: RaaS Subscription (robots-as-a-service), Purchase + Support, Lease, or Expansion (add-on to an existing agreement).",
    "PRODUCT_LINE": "Robot product line covered: Atlas, Spot or Stretch.",
    "START_DATE": "Start date of the contract term.",
    "END_DATE": "End date of the contract term.",
    "ARR_USD": "Annual recurring revenue of the contract in US dollars.",
    "TCV_USD": "Total contract value over the full term in US dollars.",
    "ROBOT_QUANTITY": "Number of robots covered by the contract.",
    "CONTRACTS.AUTO_RENEW": "TRUE if the contract renews automatically at term end.",
    "CONTRACTS.STATUS": "Contract status: Active (current term), Renewed (a past term that was renewed) or Churned (ended without renewal).",

    # Invoices
    "INVOICE_DATE": "Date the invoice was issued.",
    "DUE_DATE": "Payment due date.",
    "INVOICES.AMOUNT_USD": "Invoice amount in US dollars.",
    "PAID_DATE": "Date payment was received; NULL if unpaid.",
    "PAYMENT_STATUS": "Payment status: Paid (on time), Paid Late, Open (not yet due) or Overdue (past due and unpaid).",
    "DAYS_LATE": "Days payment was received after the due date (0 if on time, or days overdue so far if unpaid).",

    # Support tickets
    "SUPPORT_TICKETS.CATEGORY": "Ticket category: Hardware, Software, Navigation, Battery, Connectivity, Integration, Training or Billing.",
    "CATEGORY": "Ticket category: Hardware, Software, Navigation, Battery, Connectivity, Integration, Training or Billing.",
    "PRIORITY": "Ticket priority: Critical, High, Medium or Low. Drives the SLA target.",
    "CHANNEL": "Channel the ticket was raised through: Portal, Email, Phone or Field Engineer.",
    "SUBJECT": "Short ticket subject line.",
    "SUPPORT_TICKETS.DESCRIPTION": "Ticket description written by the customer or support engineer. Searchable via BD_SUPPORT_TICKET_SEARCH. Does not include the resolution.",
    "SUPPORT_TICKETS.STATUS": "Ticket status: Open or Closed.",
    "STATUS": "Ticket status: Open or Closed.",
    "OPENED_AT": "Timestamp the ticket was opened.",
    "CLOSED_AT": "Timestamp the ticket was closed; NULL while open.",
    "RESOLUTION_HOURS": "Hours from open to close; NULL while open.",
    "SLA_MET": "TRUE if the ticket was resolved within the SLA for its priority and the customer's support tier.",
    "CSAT_SCORE": "Customer satisfaction rating for the ticket, 1 (very dissatisfied) to 5 (very satisfied); NULL if not rated.",
    "ASSIGNED_TO": "Support engineer who owns the ticket.",

    # Surveys
    "SURVEY_TYPE": "Survey type: NPS (likelihood to recommend, 0-10) or CSAT (satisfaction, 1-5).",
    "SCORE": "Survey score: 0-10 for NPS, 1-5 for CSAT.",
    "NPS_CATEGORY": "Score category. NPS: Promoter (9-10), Passive (7-8), Detractor (0-6). CSAT: Satisfied (4-5), Neutral (3), Dissatisfied (1-2).",
    "VERBATIM": "Free-text comment left by the respondent. Searchable via BD_CUSTOMER_FEEDBACK_SEARCH.",
    "RESPONSE_DATE": "Date the survey was answered.",
    "RESPONSE_MONTH": "First day of the month of RESPONSE_DATE.",

    # Product usage
    "USAGE_DATE": "Calendar day the usage was recorded.",
    "PRODUCT_USAGE_DAILY.ACTIVE_ROBOTS": "Number of the customer's robots that operated on the day.",
    "PRODUCT_USAGE_DAILY.OPERATING_HOURS": "Total robot operating hours across the customer's fleet for the day.",
    "PRODUCT_USAGE_DAILY.MISSIONS_COMPLETED": "Number of autonomous missions completed across the fleet for the day.",
    "AUTONOMY_PCT": "Percentage of operating time the robots ran autonomously rather than under remote control.",
    "FEATURES_USED": "Number of distinct software features used during the day (4-12).",
    "PRODUCT_USAGE_DAILY.APP_LOGINS": "Number of logins to the fleet management app for the day.",

    # Opportunities
    "OPPORTUNITY_NAME": "Opportunity name: customer, opportunity type and product line.",
    "OPPORTUNITY_TYPE": "Opportunity type: Renewal, Expansion, Upsell, New Site or Services.",
    "STAGE": "Sales stage: Discovery, Qualification, Proposal, Negotiation, Commit, Closed Won or Closed Lost.",
    "AMOUNT_USD": "Opportunity value in US dollars.",
    "PROBABILITY_PCT": "Win probability in percent for the current stage (0-100; 100 for Closed Won, 0 for Closed Lost).",
    "CREATED_DATE": "Date the opportunity was created.",
    "CLOSE_DATE": "Expected close date for open opportunities, actual close date for closed ones.",
    "OWNER": "Account executive who owns the opportunity.",
    "IS_CLOSED": "TRUE if the opportunity is Closed Won or Closed Lost.",
    "IS_WON": "TRUE if the opportunity is Closed Won.",
    "LOSS_REASON": "Reason the opportunity was lost: Budget cuts, Insufficient ROI, Moved to competitor, Project cancelled or Unresolved reliability issues. NULL unless Closed Lost.",

    # Interactions
    "INTERACTION_TYPE": "Touchpoint type: QBR, Check-in Call, Escalation Call, Email, Site Visit, Training Session or Executive Briefing.",
    "INTERACTION_DATE": "Date of the interaction.",
    "INTERACTIONS.OWNER": "Boston Dynamics employee (CSM or account executive) who led the interaction.",
    "INTERACTIONS.SUBJECT": "Interaction subject line.",
    "SUMMARY": "Narrative notes from the interaction. Searchable via BD_INTERACTION_SEARCH.",
    "SENTIMENT": "Overall customer sentiment in the interaction: Positive, Neutral or Negative.",
    "NEXT_STEPS": "Agreed follow-up action.",

    # Fleet aggregates
    "AGE_DAYS": "Days since the robot was manufactured.",
    "TOTAL_COMPONENTS": "Number of components installed on the robot.",
    "HEALTHY_COMPONENTS": "Components with status Operational.",
    "DEGRADED_COMPONENTS": "Components with status Degraded.",
    "CRITICAL_COMPONENTS": "Components with status Needs Replacement or Failed.",
    "TELEMETRY_DATE": "Calendar day of the readings.",
    "READING_COUNT": "Number of telemetry readings on the day.",
    "AVG_BATTERY_LEVEL": "Average battery state of charge for the day, percent.",
    "MIN_BATTERY_LEVEL": "Lowest battery state of charge for the day, percent.",
    "AVG_CPU_TEMP_C": "Average compute temperature for the day, degrees Celsius.",
    "MAX_CPU_TEMP_C": "Highest compute temperature for the day, degrees Celsius.",
    "AVG_MOTOR_TEMP_C": "Average motor temperature for the day, degrees Celsius.",
    "MAX_MOTOR_TEMP_C": "Highest motor temperature for the day, degrees Celsius.",
    "AVG_VIBRATION": "Average vibration for the day, mm/s.",
    "MAX_VIBRATION": "Highest vibration for the day, mm/s.",
    "AVG_JOINT_LOAD": "Average joint load for the day, percent of rated capacity.",
    "MAX_JOINT_LOAD": "Highest joint load for the day, percent of rated capacity.",
    "AVG_SPEED_M_S": "Average speed for the day, m/s.",
    "MAX_SPEED_M_S": "Highest speed for the day, m/s.",
    "ERROR_COUNT": "Number of readings on the day that carried an error code.",
    "DISTINCT_MODES": "Number of distinct operating modes the robot used on the day.",
    "MAINTENANCE_COUNT": "Number of maintenance events for the robot and maintenance type.",
    "EVENT_COUNT": "Number of maintenance events in the group.",
    "TOTAL_COST_USD": "Total maintenance cost for the group in US dollars.",
    "AVG_COST_USD": "Average cost per maintenance event in US dollars.",
    "AVG_DURATION_MINUTES": "Average labour time per event in minutes.",
    "TOTAL_DURATION_MINUTES": "Total labour time in minutes.",
    "FIRST_MAINTENANCE_DATE": "Date of the earliest maintenance event in the group.",
    "LAST_MAINTENANCE_DATE": "Date of the most recent maintenance event in the group.",
    "PARTS_REPLACEMENT_COUNT": "Number of events in the group where parts were replaced.",
    "MAINTENANCE_MONTH": "First day of the month the maintenance was performed.",
    "INCIDENT_COUNT": "Number of incidents in the group.",
    "TOTAL_DOWNTIME_MINUTES": "Total incident downtime in minutes.",
    "AVG_DOWNTIME_MINUTES": "Average downtime per incident in minutes.",
    "RESOLVED_COUNT": "Incidents that have been resolved.",
    "UNRESOLVED_COUNT": "Incidents still open (no RESOLVED_AT).",
    "FIRST_INCIDENT_DATE": "Date of the earliest incident in the group.",
    "LAST_INCIDENT_DATE": "Date of the most recent incident in the group.",
    "ACTIVE_DEPLOYMENTS": "Number of deployment sites for the customer (all statuses).",
    "TOTAL_ROBOTS": "Number of robots deployed across the customer's sites.",
    "ACTIVE_ROBOTS": "Number of robots with status Active.",
    "ROBOTS_IN_MAINTENANCE": "Number of robots with status Maintenance.",
    "ATLAS_COUNT": "Number of Atlas robots.",
    "SPOT_COUNT": "Number of Spot robots.",
    "STRETCH_COUNT": "Number of Stretch robots.",
    "TOTAL_MAINTENANCE_COST": "Total maintenance cost over all history in US dollars.",
    "TOTAL_INCIDENTS": "Total number of incidents over all history.",
    "TOTAL_UNITS": "Number of robots of the model.",
    "ACTIVE_UNITS": "Number of robots of the model with status Active.",
    "AVG_AGE_DAYS": "Average robot age in days since manufacture.",
    "FLEET_AVG_BATTERY": "Average battery level across all readings for the model, percent.",
    "FLEET_AVG_MOTOR_TEMP": "Average motor temperature across all readings for the model, degrees Celsius.",
    "FLEET_AVG_VIBRATION": "Average vibration across all readings for the model, mm/s.",
    "INCIDENTS_PER_ROBOT": "Total incidents divided by number of robots of the model.",
    "AVG_MAINTENANCE_COST_PER_ROBOT": "Total maintenance cost divided by number of robots of the model, US dollars.",
    "DAYS_SINCE_DEPLOYMENT": "Days since the site went live.",
    "DEPLOYMENT_STATUS": "Site status: Active, Maintenance or Decommissioned.",
    "DEPLOYMENT_PERFORMANCE.ROBOT_COUNT": "Number of robots assigned to the site.",
    "DEPLOYMENT_PERFORMANCE.ACTIVE_ROBOTS": "Robots at the site with status Active.",

    # Customer 360
    "TENURE_DAYS": "Days from CUSTOMER_SINCE to the as-of date.",
    "DAYS_TO_RENEWAL": "Days from today until CONTRACT_END_DATE (negative if past due). NULL for churned customers.",
    "AS_OF_DATE": "Reference date for all rolling windows: today for current customers, the churn date (CONTRACT_END_DATE) for churned customers.",
    "SITE_COUNT": "Number of deployment sites for the customer.",
    "CURRENT_ARR_USD": "Annual recurring revenue from the customer's Active contracts, US dollars. 0 for churned customers.",
    "CHURNED_ARR_USD": "ARR of the customer's contracts with status Churned, US dollars.",
    "LIFETIME_CONTRACT_VALUE_USD": "Sum of total contract value across all of the customer's contracts, US dollars.",
    "CONTRACT_COUNT": "Number of contracts (all terms and expansions) for the customer.",
    "RENEWAL_COUNT": "Number of past contract terms that were renewed.",
    "PRIMARY_CONTRACT_TYPE": "Main commercial model of the account (RaaS Subscription, Purchase + Support or Lease), excluding Expansion add-ons.",
    "PRIMARY_PRODUCT_LINE": "Main robot product line under contract (Atlas, Spot or Stretch).",
    "AUTO_RENEW": "TRUE if any Active contract auto-renews.",
    "INCIDENTS_90D": "Robot incidents at the customer's sites in the 90 days before the as-of date.",
    "CRITICAL_INCIDENTS_90D": "Critical-severity incidents in the 90 days before the as-of / snapshot date.",
    "DOWNTIME_MINUTES_90D": "Incident downtime in minutes in the 90 days before the as-of date.",
    "INCIDENTS_PER_ROBOT_90D": "INCIDENTS_90D divided by TOTAL_ROBOTS.",
    "TICKETS_90D": "Support tickets opened in the 90 days before the as-of date.",
    "HIGH_PRIORITY_TICKETS_90D": "Critical or High priority tickets opened in the 90 days before the as-of / snapshot date.",
    "OPEN_TICKETS": "Tickets opened in the last 90 days that are still Open.",
    "TICKETS_PER_ROBOT_90D": "Tickets opened in the last 90 days divided by TOTAL_ROBOTS.",
    "SLA_MET_PCT_90D": "Percentage of tickets opened in the last 90 days that met SLA (0-100).",
    "AVG_TICKET_CSAT_90D": "Average ticket CSAT (1-5) for tickets opened in the last 90 days.",
    "AVG_RESOLUTION_HOURS_90D": "Average hours to resolve tickets opened in the last 90 days.",
    "LATEST_NPS": "Most recent NPS score (0-10) from any contact at the customer.",
    "LATEST_NPS_CATEGORY": "Category of the most recent NPS response: Promoter, Passive or Detractor.",
    "AVG_NPS_6M": "Average NPS score (0-10, not the -100 to +100 index) over the 180 days before the as-of / snapshot date.",
    "AVG_NPS_PRIOR_6M": "Average NPS score (0-10) for responses older than 180 days before the as-of date.",
    "NPS_TREND": "Change in average NPS score: recent period minus earlier period. Negative means sentiment is falling.",
    "AVG_ACTIVE_ROBOTS_30D": "Average daily active robots over the last 30 days.",
    "AVG_ACTIVE_ROBOTS_PRIOR_90D": "Average daily active robots over the 90 days before the last 30 (days 31-120).",
    "UTILIZATION_PCT_30D": "Average daily active robots over the last 30 days as a percentage of TOTAL_ROBOTS.",
    "USAGE_TREND_PCT": "Percent change in average daily active robots, last 30 days versus the prior 90 days. Negative means declining adoption.",
    "OPERATING_HOURS_30D": "Total robot operating hours over the last 30 days.",
    "MISSIONS_30D": "Missions completed over the last 30 days.",
    "AUTONOMY_PCT_30D": "Average autonomy rate (percent of time operating autonomously) over the last 30 days.",
    "LAST_USAGE_DATE": "Most recent day with recorded usage.",
    "LATE_PAYMENT_PCT_12M": "Percentage of invoices in the last 12 months that were paid late or are overdue (0-100).",
    "OVERDUE_AMOUNT_USD": "Total amount of invoices currently Overdue in the last 12 months, US dollars.",
    "AVG_DAYS_LATE_12M": "Average days late across invoices in the last 12 months.",
    "OPEN_PIPELINE_USD": "Total amount of open (not closed) opportunities, US dollars, including renewals.",
    "OPEN_EXPANSION_PIPELINE_USD": "Total amount of open non-renewal opportunities (Expansion, Upsell, New Site, Services), US dollars.",
    "EXPANSION_WON_12M_USD": "Value of non-renewal opportunities won in the last 12 months, US dollars.",
    "EXPANSION_WINS_12M": "Number of non-renewal opportunities won in the last 12 months.",
    "RENEWAL_STAGE": "Sales stage of the open renewal opportunity, if any.",
    "RENEWAL_PROBABILITY_PCT": "Win probability of the open renewal opportunity, percent.",
    "INTERACTIONS_90D": "Customer interactions in the 90 days before the as-of / snapshot date.",
    "NEGATIVE_SENTIMENT_PCT_90D": "Percentage of interactions in the last 90 days with Negative sentiment (0-100).",
    "LAST_INTERACTION_DATE": "Date of the most recent interaction.",
    "LAST_INTERACTION_TYPE": "Type of the most recent interaction.",
    "DAYS_SINCE_LAST_INTERACTION": "Days from the last interaction to the as-of date.",
    "CHURN_RISK_SCORE": "Predicted probability (0-1) that the customer churns within 180 days, from the BD_CHURN_RISK XGBoost model.",
    "CHURN_RISK_TIER": "Churn risk band from CHURN_RISK_SCORE: High (above 0.6), Medium (0.3-0.6) or Low (0.3 or below).",
    "HEALTH_SCORE": "Customer health score 0-100 from the BD_CUSTOMER_HEALTH_SCORE model; higher is healthier.",
    "HEALTH_BAND": "Health band from HEALTH_SCORE: Healthy (75 or more), Monitor (50-75) or At Risk (below 50).",
    "EXPANSION_PROPENSITY": "Predicted probability (0-1) that the customer wins an expansion within 180 days, from the BD_EXPANSION_PROPENSITY model.",
    "EXPANSION_TIER": "Expansion band from EXPANSION_PROPENSITY: High (above 0.6), Medium (0.3-0.6) or Low (0.3 or below).",
    "TOP_RISK_DRIVERS": "Features pushing churn risk up most for this customer (SHAP contributions), or 'No significant risk drivers'.",
    "ML_SCORED_AT": "Timestamp the ML scores were produced.",
    "MODEL_VERSION": "Model Registry version used for scoring (for example V1).",
    "SCORED_AT": "Timestamp the scores were produced.",

    # ML features
    "SNAPSHOT_K": "Snapshot index: 0 is the scoring row at the as-of date; 1-9 are training snapshots 30, 60 ... 270 days earlier.",
    "SNAPSHOT_DATE": "Point-in-time date the features are computed as of. All windows end on this date, so there is no look-ahead.",
    "IS_SCORING_ROW": "TRUE for SNAPSHOT_K = 0, the row used for current scoring (no label).",
    "CUSTOMER_ML_FEATURES.TENURE_DAYS": "Days from CUSTOMER_SINCE to SNAPSHOT_DATE.",
    "CUSTOMER_ML_FEATURES.INCIDENTS_PER_ROBOT_90D": "Incidents in the 90 days before SNAPSHOT_DATE divided by TOTAL_ROBOTS.",
    "CUSTOMER_ML_FEATURES.TICKETS_PER_ROBOT_90D": "Tickets opened in the 90 days before SNAPSHOT_DATE divided by TOTAL_ROBOTS.",
    "CUSTOMER_ML_FEATURES.SLA_MET_PCT_90D": "Percentage of tickets opened in the 90 days before SNAPSHOT_DATE and closed by then that met SLA.",
    "CUSTOMER_ML_FEATURES.AVG_TICKET_CSAT_90D": "Average CSAT of tickets opened in the 90 days before SNAPSHOT_DATE and closed by then.",
    "CUSTOMER_ML_FEATURES.AVG_RESOLUTION_HOURS_90D": "Average resolution hours of tickets opened in the 90 days before SNAPSHOT_DATE and closed by then.",
    "CUSTOMER_ML_FEATURES.NPS_TREND": "Average NPS in the 90 days before SNAPSHOT_DATE minus average NPS in the 90 days before that.",
    "CUSTOMER_ML_FEATURES.UTILIZATION_PCT_30D": "Average daily active robots in the 30 days before SNAPSHOT_DATE as a percentage of TOTAL_ROBOTS.",
    "CUSTOMER_ML_FEATURES.USAGE_TREND_PCT": "Percent change in average daily active robots, 30 days before SNAPSHOT_DATE versus the 90 days before that.",
    "CUSTOMER_ML_FEATURES.AUTONOMY_PCT_30D": "Average autonomy rate in the 30 days before SNAPSHOT_DATE.",
    "CUSTOMER_ML_FEATURES.LATE_PAYMENT_PCT_12M": "Percentage of invoices due in the 12 months before SNAPSHOT_DATE that were paid late.",
    "CUSTOMER_ML_FEATURES.AVG_DAYS_LATE_12M": "Average days late of invoices due in the 12 months before SNAPSHOT_DATE.",
    "CUSTOMER_ML_FEATURES.NEGATIVE_SENTIMENT_PCT_90D": "Percentage of interactions in the 90 days before SNAPSHOT_DATE with Negative sentiment.",
    "CHURN_NEXT_180D": "Training label: 1 if the customer churned within 180 days after SNAPSHOT_DATE, 0 if not, NULL for the scoring row or when the 180-day window has not elapsed.",
    "EXPANSION_NEXT_180D": "Training label: 1 if a non-renewal opportunity was won within 180 days after SNAPSHOT_DATE, 0 if not, NULL for the scoring row or when the window has not elapsed.",

    # Revenue monthly
    "REVENUE_MONTH": "First day of the invoice month.",
    "INVOICE_COUNT": "Number of invoices issued in the month.",
    "INVOICED_USD": "Total amount invoiced in the month, US dollars.",
    "COLLECTED_USD": "Amount from the month's invoices that has been paid (on time or late), US dollars.",
    "PAID_LATE_USD": "Amount from the month's invoices that was paid after the due date, US dollars.",
    "OVERDUE_USD": "Amount from the month's invoices that is past due and unpaid, US dollars.",
    "OPEN_USD": "Amount from the month's invoices that is unpaid but not yet due, US dollars.",
    "LATE_INVOICE_COUNT": "Number of the month's invoices that were paid late or are overdue.",
    "AVG_DAYS_LATE": "Average days late across the month's invoices.",

    # Support ticket analysis
    "OPENED_MONTH": "First day of the month the ticket was opened.",

    # Usage trend
    "USAGE_MONTH": "First day of the usage month.",
    "DAYS_REPORTED": "Number of days in the month with usage data.",
    "AVG_ACTIVE_ROBOTS": "Average daily active robots in the month.",
    "UTILIZATION_PCT": "Average daily active robots as a percentage of the customer's total robots.",
    "CUSTOMER_USAGE_TREND.OPERATING_HOURS": "Total robot operating hours in the month.",
    "CUSTOMER_USAGE_TREND.MISSIONS_COMPLETED": "Total missions completed in the month.",
    "AVG_AUTONOMY_PCT": "Average daily autonomy rate in the month, percent.",
    "AVG_FEATURES_USED": "Average number of distinct features used per day in the month.",
    "CUSTOMER_USAGE_TREND.APP_LOGINS": "Total fleet app logins in the month.",

    # Sales pipeline
    "WEIGHTED_AMOUNT_USD": "AMOUNT_USD multiplied by PROBABILITY_PCT / 100, US dollars.",
    "CLOSE_QUARTER": "First day of the calendar quarter of CLOSE_DATE.",
    "SALES_CYCLE_DAYS": "Days from CREATED_DATE to CLOSE_DATE.",
}


def describe(table, col):
    for key in (f"{table}.{col}", col):
        if key in C:
            return C[key]
    return None


def q(text):
    return text.replace("'", "''")


def inventory(conn):
    cur = conn.cursor()
    cur.execute("""
        SELECT c.table_schema, c.table_name, t.table_type, c.column_name
        FROM BD_INTELLIGENCE.INFORMATION_SCHEMA.COLUMNS c
        JOIN BD_INTELLIGENCE.INFORMATION_SCHEMA.TABLES t USING (table_catalog, table_schema, table_name)
        WHERE c.table_schema IN ('RAW', 'ANALYTICS')
        ORDER BY c.table_schema DESC, c.table_name, c.ordinal_position""")
    objs = {}
    for schema, table, ttype, col in cur.fetchall():
        objs.setdefault((schema, table, ttype), []).append(col)
    return objs


def table_statements(schema, table, cols):
    fq = f"BD_INTELLIGENCE.{schema}.{table}"
    out = [f"COMMENT ON TABLE {fq} IS '{q(OBJECTS[f'{schema}.{table}'])}';"]
    clauses = ",\n    ".join(f"{c} COMMENT '{q(describe(table, c))}'" for c in cols)
    out.append(f"ALTER TABLE {fq} ALTER\n    {clauses};")
    return out


def replace_block(text, begin, end, body):
    pattern = re.compile(re.escape(begin) + r".*?" + re.escape(end), re.S)
    block = f"{begin}\n{body}\n{end}"
    if pattern.search(text):
        return pattern.sub(lambda _: block, text)
    return text.rstrip() + "\n\n" + block + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--connection", default="AWS161")
    parser.add_argument("--apply", action="store_true", help="apply RAW table and CUSTOMER_ML_SCORES comments live")
    args = parser.parse_args()

    conn = snowflake.connector.connect(connection_name=args.connection)
    objs = inventory(conn)

    missing = [f"{s}.{t}.{c}" for (s, t, _), cols in objs.items() for c in cols if not describe(t, c)]
    missing += [f"{s}.{t} (object)" for (s, t, _) in objs if f"{s}.{t}" not in OBJECTS]
    if missing:
        raise SystemExit("Missing descriptions:\n  " + "\n  ".join(missing))

    # RAW tables -> 02_create_tables.sql
    raw_stmts = []
    for (s, t, ttype), cols in objs.items():
        if s == "RAW":
            raw_stmts += table_statements(s, t, cols)
    TABLES_SQL.write_text(replace_block(
        TABLES_SQL.read_text(), "-- @comments-begin (generated by scripts/build_comments.py; do not edit by hand)",
        "-- @comments-end", "\n".join(raw_stmts)))

    # Views and CUSTOMER_ML_SCORES -> 04_create_views.sql
    vtext = VIEWS_SQL.read_text()
    view_count = 0
    for (s, t, ttype), cols in objs.items():
        if s != "ANALYTICS" or ttype != "VIEW":
            continue
        width = max(len(c) for c in cols)
        col_list = ",\n".join(f"    {c.ljust(width)} COMMENT '{q(describe(t, c))}'" for c in cols)
        header = (f"CREATE OR REPLACE VIEW {t}\n-- @cols-begin\n(\n{col_list}\n)\n"
                  f"COMMENT = '{q(OBJECTS[f'{s}.{t}'])}'\n-- @cols-end\nAS")
        pattern = re.compile(rf"CREATE OR REPLACE VIEW {t}\b(?:\n-- @cols-begin.*?-- @cols-end)?\s*\nAS|CREATE OR REPLACE VIEW {t} AS", re.S)
        vtext, n = pattern.subn(lambda _: header, vtext, count=1)
        if n != 1:
            raise SystemExit(f"Could not find CREATE OR REPLACE VIEW {t} in {VIEWS_SQL}")
        view_count += 1
    ml_cols = objs[("ANALYTICS", "CUSTOMER_ML_SCORES", "BASE TABLE")]
    ml_stmts = table_statements("ANALYTICS", "CUSTOMER_ML_SCORES", ml_cols)
    vtext = replace_block(vtext, "-- @comments-begin (generated by scripts/build_comments.py; do not edit by hand)",
                          "-- @comments-end", "\n".join(ml_stmts))
    VIEWS_SQL.write_text(vtext)

    total_cols = sum(len(c) for c in objs.values())
    print(f"Described {len(objs)} objects, {total_cols} columns; {view_count} view headers rewritten")

    if args.apply:
        cur = conn.cursor()
        for stmt in raw_stmts + ml_stmts:
            cur.execute(stmt.rstrip(";"))
        print(f"Applied {len(raw_stmts) + len(ml_stmts)} table/column comment statements")
    conn.close()


if __name__ == "__main__":
    main()
