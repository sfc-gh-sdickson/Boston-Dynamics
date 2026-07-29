-- Expanded maintenance data window from 90 days to 12 months to support trend queries
-- Co-authored with CoCo
/*=============================================================================
  Boston Dynamics Intelligence Agent
  Step 3: Synthetic Data Generation
  
  Execution Order: 3 of 9
  Description: Generates realistic synthetic data for all tables including
               robots, telemetry, components, maintenance, customers,
               deployments, incidents, knowledge base articles, and firmware.
=============================================================================*/

USE DATABASE BD_INTELLIGENCE;
USE SCHEMA RAW;
USE WAREHOUSE BOSTON_DYNAMICS_WH;

-- ============================================================================
-- CUSTOMERS (30 customers across industries)
-- ============================================================================
INSERT INTO CUSTOMERS
SELECT
    'CUST-' || LPAD(SEQ4()::VARCHAR, 4, '0') AS CUSTOMER_ID,
    CASE MOD(SEQ4(), 30)
        WHEN 0 THEN 'Tesla Gigafactory'
        WHEN 1 THEN 'Amazon Fulfillment'
        WHEN 2 THEN 'Shell Energy'
        WHEN 3 THEN 'Chevron Refinery'
        WHEN 4 THEN 'US Army Corps'
        WHEN 5 THEN 'NASA JPL'
        WHEN 6 THEN 'Toyota Manufacturing'
        WHEN 7 THEN 'Samsung Electronics'
        WHEN 8 THEN 'DHL Logistics'
        WHEN 9 THEN 'BP Energy'
        WHEN 10 THEN 'Ford Motor Company'
        WHEN 11 THEN 'Caterpillar Inc'
        WHEN 12 THEN 'Rio Tinto Mining'
        WHEN 13 THEN 'Lockheed Martin'
        WHEN 14 THEN 'Procter and Gamble'
        WHEN 15 THEN 'Walmart Distribution'
        WHEN 16 THEN 'General Electric'
        WHEN 17 THEN 'Siemens Energy'
        WHEN 18 THEN 'Vale Mining'
        WHEN 19 THEN 'FedEx Ground'
        WHEN 20 THEN 'BMW Manufacturing'
        WHEN 21 THEN 'Dow Chemical'
        WHEN 22 THEN 'BHP Group Mining'
        WHEN 23 THEN 'Northrop Grumman'
        WHEN 24 THEN 'Johnson and Johnson'
        WHEN 25 THEN 'Target Distribution'
        WHEN 26 THEN 'Honeywell Aerospace'
        WHEN 27 THEN 'Duke Energy'
        WHEN 28 THEN 'Anglo American Mining'
        WHEN 29 THEN 'SpaceX'
    END AS CUSTOMER_NAME,
    CASE 
        WHEN MOD(SEQ4(), 30) IN (0,6,7,10,20) THEN 'Automotive Manufacturing'
        WHEN MOD(SEQ4(), 30) IN (1,8,15,19,25) THEN 'Logistics & Warehousing'
        WHEN MOD(SEQ4(), 30) IN (2,3,9,17,27) THEN 'Energy & Utilities'
        WHEN MOD(SEQ4(), 30) IN (4,5,13,23,29) THEN 'Aerospace & Defense'
        WHEN MOD(SEQ4(), 30) IN (12,18,22,28) THEN 'Mining & Resources'
        WHEN MOD(SEQ4(), 30) IN (11,14,16,21,24,26) THEN 'Industrial Manufacturing'
    END AS INDUSTRY,
    CASE WHEN MOD(SEQ4(), 3) = 0 THEN 'Enterprise' WHEN MOD(SEQ4(), 3) = 1 THEN 'Large' ELSE 'Mid-Market' END AS COMPANY_SIZE,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'North America'
        WHEN 1 THEN 'Europe'
        WHEN 2 THEN 'Asia Pacific'
        WHEN 3 THEN 'North America'
        WHEN 4 THEN 'South America'
    END AS REGION,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'United States'
        WHEN 1 THEN 'Germany'
        WHEN 2 THEN 'Japan'
        WHEN 3 THEN 'United States'
        WHEN 4 THEN 'Brazil'
        WHEN 5 THEN 'United Kingdom'
        WHEN 6 THEN 'Australia'
        WHEN 7 THEN 'Canada'
    END AS COUNTRY,
    DATEADD(DAY, -1 * UNIFORM(180, 1095, RANDOM()), CURRENT_DATE()) AS CONTRACT_START_DATE,
    DATEADD(DAY, UNIFORM(365, 1095, RANDOM()), CURRENT_DATE()) AS CONTRACT_END_DATE,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'Sarah Chen'
        WHEN 1 THEN 'Marcus Johnson'
        WHEN 2 THEN 'Elena Rodriguez'
        WHEN 3 THEN 'James Park'
        WHEN 4 THEN 'Priya Patel'
        WHEN 5 THEN 'David Thompson'
    END AS ACCOUNT_MANAGER,
    CASE WHEN MOD(SEQ4(), 4) = 0 THEN 'Platinum' WHEN MOD(SEQ4(), 4) = 1 THEN 'Gold' WHEN MOD(SEQ4(), 4) = 2 THEN 'Silver' ELSE 'Bronze' END AS SUPPORT_TIER
FROM TABLE(GENERATOR(ROWCOUNT => 30));

-- ============================================================================
-- DEPLOYMENTS (60 deployment sites)
-- ============================================================================
INSERT INTO DEPLOYMENTS
SELECT
    'DEP-' || LPAD(SEQ4()::VARCHAR, 4, '0') AS DEPLOYMENT_ID,
    'CUST-' || LPAD((MOD(SEQ4(), 30))::VARCHAR, 4, '0') AS CUSTOMER_ID,
    CASE MOD(SEQ4(), 20)
        WHEN 0 THEN 'Assembly Line Alpha'
        WHEN 1 THEN 'Warehouse Zone B'
        WHEN 2 THEN 'Offshore Platform 7'
        WHEN 3 THEN 'Refinery Section C'
        WHEN 4 THEN 'Test Range Delta'
        WHEN 5 THEN 'Clean Room 12'
        WHEN 6 THEN 'Paint Shop East'
        WHEN 7 THEN 'Fabrication Hall'
        WHEN 8 THEN 'Distribution Hub 3'
        WHEN 9 THEN 'Pipeline Inspection'
        WHEN 10 THEN 'Production Floor Main'
        WHEN 11 THEN 'Underground Level 2'
        WHEN 12 THEN 'Open Pit Section A'
        WHEN 13 THEN 'Hangar Bay 4'
        WHEN 14 THEN 'Packaging Center'
        WHEN 15 THEN 'Cold Storage Wing'
        WHEN 16 THEN 'Turbine Hall'
        WHEN 17 THEN 'Substation Grid'
        WHEN 18 THEN 'Mine Shaft 3'
        WHEN 19 THEN 'Sorting Facility'
    END || ' - Site ' || SEQ4()::VARCHAR AS SITE_NAME,
    CASE MOD(SEQ4(), 7)
        WHEN 0 THEN 'Manufacturing Floor'
        WHEN 1 THEN 'Warehouse'
        WHEN 2 THEN 'Outdoor Industrial'
        WHEN 3 THEN 'Underground'
        WHEN 4 THEN 'Laboratory'
        WHEN 5 THEN 'Construction Site'
        WHEN 6 THEN 'Hazardous Area'
    END AS SITE_TYPE,
    DATEADD(DAY, -1 * UNIFORM(30, 730, RANDOM()), CURRENT_DATE()) AS DEPLOYMENT_DATE,
    UNIFORM(1, 12, RANDOM()) AS ROBOT_COUNT,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'Autonomous Inspection'
        WHEN 1 THEN 'Material Handling'
        WHEN 2 THEN 'Remote Monitoring'
        WHEN 3 THEN 'Hazardous Environment Inspection'
        WHEN 4 THEN 'Quality Assurance'
        WHEN 5 THEN 'Inventory Management'
        WHEN 6 THEN 'Security Patrol'
        WHEN 7 THEN 'Data Collection'
    END AS PRIMARY_USE_CASE,
    CASE MOD(SEQ4(), 4) WHEN 0 THEN 'Indoor' WHEN 1 THEN 'Outdoor' WHEN 2 THEN 'Mixed' ELSE 'Hazardous' END AS ENVIRONMENT,
    CASE WHEN MOD(SEQ4(), 10) < 8 THEN 'Active' WHEN MOD(SEQ4(), 10) = 8 THEN 'Maintenance' ELSE 'Decommissioned' END AS STATUS,
    UNIFORM(-90.0, 90.0, RANDOM())::FLOAT AS LATITUDE,
    UNIFORM(-180.0, 180.0, RANDOM())::FLOAT AS LONGITUDE
FROM TABLE(GENERATOR(ROWCOUNT => 60));

-- ============================================================================
-- ROBOTS (200 robots: Atlas, Spot, Stretch)
-- ============================================================================
INSERT INTO ROBOTS
SELECT
    'BOT-' || LPAD(SEQ4()::VARCHAR, 5, '0') AS ROBOT_ID,
    CASE 
        WHEN MOD(SEQ4(), 3) = 0 THEN 'Atlas-' || LPAD(SEQ4()::VARCHAR, 3, '0')
        WHEN MOD(SEQ4(), 3) = 1 THEN 'Spot-' || LPAD(SEQ4()::VARCHAR, 3, '0')
        ELSE 'Stretch-' || LPAD(SEQ4()::VARCHAR, 3, '0')
    END AS ROBOT_NAME,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'Atlas' WHEN 1 THEN 'Spot' ELSE 'Stretch' END AS ROBOT_MODEL,
    'BD-' || UPPER(SUBSTR(MD5(SEQ4()::VARCHAR), 1, 12)) AS SERIAL_NUMBER,
    DATEADD(DAY, -1 * UNIFORM(90, 900, RANDOM()), CURRENT_DATE()) AS MANUFACTURE_DATE,
    CASE MOD(SEQ4(), 3)
        WHEN 0 THEN '3.' || UNIFORM(1,9,RANDOM()) || '.' || UNIFORM(0,20,RANDOM())
        WHEN 1 THEN '4.' || UNIFORM(1,9,RANDOM()) || '.' || UNIFORM(0,20,RANDOM())
        ELSE '2.' || UNIFORM(1,9,RANDOM()) || '.' || UNIFORM(0,20,RANDOM())
    END AS FIRMWARE_VERSION,
    CASE 
        WHEN MOD(SEQ4(), 20) < 14 THEN 'Active'
        WHEN MOD(SEQ4(), 20) < 17 THEN 'Idle'
        WHEN MOD(SEQ4(), 20) < 19 THEN 'Maintenance'
        ELSE 'Decommissioned'
    END AS STATUS,
    'DEP-' || LPAD((MOD(SEQ4(), 60))::VARCHAR, 4, '0') AS DEPLOYMENT_ID,
    CURRENT_TIMESTAMP() AS CREATED_AT,
    CURRENT_TIMESTAMP() AS UPDATED_AT
FROM TABLE(GENERATOR(ROWCOUNT => 200));

-- ============================================================================
-- COMPONENTS (1000 components across all robots)
-- ============================================================================
INSERT INTO COMPONENTS
SELECT
    'COMP-' || LPAD(SEQ4()::VARCHAR, 5, '0') AS COMPONENT_ID,
    'BOT-' || LPAD((MOD(SEQ4(), 200))::VARCHAR, 5, '0') AS ROBOT_ID,
    CASE MOD(SEQ4(), 10)
        WHEN 0 THEN 'Motor'
        WHEN 1 THEN 'Battery'
        WHEN 2 THEN 'Sensor'
        WHEN 3 THEN 'Joint Actuator'
        WHEN 4 THEN 'Camera'
        WHEN 5 THEN 'LiDAR'
        WHEN 6 THEN 'Gripper'
        WHEN 7 THEN 'Communication Module'
        WHEN 8 THEN 'Controller Board'
        WHEN 9 THEN 'Hydraulic Pump'
    END AS COMPONENT_TYPE,
    CASE MOD(SEQ4(), 10)
        WHEN 0 THEN CASE MOD(SEQ4(), 3) WHEN 0 THEN 'Hip Motor' WHEN 1 THEN 'Knee Motor' ELSE 'Shoulder Motor' END
        WHEN 1 THEN CASE MOD(SEQ4(), 2) WHEN 0 THEN 'Primary Battery Pack' ELSE 'Auxiliary Battery' END
        WHEN 2 THEN CASE MOD(SEQ4(), 3) WHEN 0 THEN 'Temperature Sensor' WHEN 1 THEN 'Vibration Sensor' ELSE 'Force Torque Sensor' END
        WHEN 3 THEN CASE MOD(SEQ4(), 3) WHEN 0 THEN 'Elbow Actuator' WHEN 1 THEN 'Wrist Actuator' ELSE 'Ankle Actuator' END
        WHEN 4 THEN CASE MOD(SEQ4(), 2) WHEN 0 THEN 'Stereo Camera' ELSE 'Depth Camera' END
        WHEN 5 THEN 'Velodyne LiDAR Unit'
        WHEN 6 THEN CASE MOD(SEQ4(), 2) WHEN 0 THEN 'Precision Gripper' ELSE 'Vacuum Gripper' END
        WHEN 7 THEN CASE MOD(SEQ4(), 2) WHEN 0 THEN '5G Radio Module' ELSE 'WiFi 6E Module' END
        WHEN 8 THEN CASE MOD(SEQ4(), 2) WHEN 0 THEN 'Main Controller' ELSE 'Safety Controller' END
        WHEN 9 THEN 'Hydraulic Power Unit'
    END AS COMPONENT_NAME,
    DATEADD(DAY, -1 * UNIFORM(30, 800, RANDOM()), CURRENT_DATE()) AS INSTALL_DATE,
    CASE MOD(SEQ4(), 10)
        WHEN 0 THEN UNIFORM(500, 1500, RANDOM())
        WHEN 1 THEN UNIFORM(365, 730, RANDOM())
        WHEN 2 THEN UNIFORM(1000, 2000, RANDOM())
        WHEN 3 THEN UNIFORM(600, 1200, RANDOM())
        WHEN 4 THEN UNIFORM(800, 1800, RANDOM())
        WHEN 5 THEN UNIFORM(1200, 2500, RANDOM())
        WHEN 6 THEN UNIFORM(400, 1000, RANDOM())
        WHEN 7 THEN UNIFORM(1500, 3000, RANDOM())
        WHEN 8 THEN UNIFORM(2000, 4000, RANDOM())
        WHEN 9 THEN UNIFORM(500, 1000, RANDOM())
    END AS EXPECTED_LIFESPAN_DAYS,
    UNIFORM(100, 15000, RANDOM())::FLOAT AS CURRENT_RUNTIME_HOURS,
    CASE 
        WHEN MOD(SEQ4(), 20) < 15 THEN 'Operational'
        WHEN MOD(SEQ4(), 20) < 17 THEN 'Degraded'
        WHEN MOD(SEQ4(), 20) < 19 THEN 'Needs Replacement'
        ELSE 'Failed'
    END AS STATUS,
    DATEADD(DAY, -1 * UNIFORM(1, 90, RANDOM()), CURRENT_DATE()) AS LAST_INSPECTION_DATE
FROM TABLE(GENERATOR(ROWCOUNT => 1000));

-- ============================================================================
-- ROBOT_TELEMETRY (50,000 telemetry readings over 90 days)
-- ============================================================================
INSERT INTO ROBOT_TELEMETRY
SELECT
    'TEL-' || LPAD(SEQ4()::VARCHAR, 7, '0') AS TELEMETRY_ID,
    'BOT-' || LPAD((MOD(SEQ4(), 200))::VARCHAR, 5, '0') AS ROBOT_ID,
    DATEADD(SECOND, -1 * UNIFORM(0, 7776000, RANDOM()), CURRENT_TIMESTAMP()) AS TIMESTAMP,
    ROUND(UNIFORM(5.0, 100.0, RANDOM())::FLOAT, 1) AS BATTERY_LEVEL,
    ROUND(UNIFORM(25.0, 85.0, RANDOM())::FLOAT, 1) AS CPU_TEMPERATURE_C,
    ROUND(UNIFORM(30.0, 110.0, RANDOM())::FLOAT, 1) AS MOTOR_TEMPERATURE_C,
    ROUND(UNIFORM(0.1, 15.0, RANDOM())::FLOAT, 2) AS VIBRATION_MM_S,
    ROUND(UNIFORM(5.0, 98.0, RANDOM())::FLOAT, 1) AS JOINT_LOAD_PERCENT,
    ROUND(UNIFORM(0.0, 3.5, RANDOM())::FLOAT, 2) AS SPEED_M_S,
    ROUND(UNIFORM(-15.0, 15.0, RANDOM())::FLOAT, 2) AS ORIENTATION_ROLL,
    ROUND(UNIFORM(-20.0, 20.0, RANDOM())::FLOAT, 2) AS ORIENTATION_PITCH,
    ROUND(UNIFORM(-180.0, 180.0, RANDOM())::FLOAT, 2) AS ORIENTATION_YAW,
    ROUND(UNIFORM(-50.0, 50.0, RANDOM())::FLOAT, 2) AS LOCATION_X,
    ROUND(UNIFORM(-50.0, 50.0, RANDOM())::FLOAT, 2) AS LOCATION_Y,
    ROUND(UNIFORM(0.0, 5.0, RANDOM())::FLOAT, 2) AS LOCATION_Z,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'Autonomous Navigation'
        WHEN 1 THEN 'Remote Control'
        WHEN 2 THEN 'Inspection Mode'
        WHEN 3 THEN 'Material Handling'
        WHEN 4 THEN 'Idle Standby'
        WHEN 5 THEN 'Charging'
    END AS OPERATIONAL_MODE,
    CASE WHEN UNIFORM(1, 100, RANDOM()) <= 5 THEN 'ERR-' || LPAD(UNIFORM(100, 999, RANDOM())::VARCHAR, 3, '0') ELSE NULL END AS ERROR_CODE
FROM TABLE(GENERATOR(ROWCOUNT => 50000));

-- ============================================================================
-- MAINTENANCE_RECORDS (2000 maintenance events)
-- ============================================================================
INSERT INTO MAINTENANCE_RECORDS
SELECT
    'MNT-' || LPAD(SEQ4()::VARCHAR, 5, '0') AS MAINTENANCE_ID,
    'BOT-' || LPAD((MOD(SEQ4(), 200))::VARCHAR, 5, '0') AS ROBOT_ID,
    CASE WHEN UNIFORM(1, 10, RANDOM()) <= 7 THEN 'COMP-' || LPAD((MOD(SEQ4(), 1000))::VARCHAR, 5, '0') ELSE NULL END AS COMPONENT_ID,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'Preventive'
        WHEN 1 THEN 'Corrective'
        WHEN 2 THEN 'Predictive'
        WHEN 3 THEN 'Firmware Update'
        WHEN 4 THEN 'Calibration'
    END AS MAINTENANCE_TYPE,
    CASE MOD(SEQ4(), 10)
        WHEN 0 THEN 'Routine motor inspection and lubrication completed'
        WHEN 1 THEN 'Battery health check and cell balancing performed'
        WHEN 2 THEN 'Replaced worn joint actuator bearings'
        WHEN 3 THEN 'Firmware upgraded to latest stable release'
        WHEN 4 THEN 'LiDAR sensor recalibrated after drift detected'
        WHEN 5 THEN 'Emergency motor replacement due to overheating'
        WHEN 6 THEN 'Camera lens cleaned and alignment verified'
        WHEN 7 THEN 'Hydraulic system pressure test and fluid replacement'
        WHEN 8 THEN 'Communication module antenna replacement'
        WHEN 9 THEN 'Full system diagnostic and safety certification'
    END AS DESCRIPTION,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'Alex Martinez'
        WHEN 1 THEN 'Jordan Lee'
        WHEN 2 THEN 'Sam Nguyen'
        WHEN 3 THEN 'Robin Patel'
        WHEN 4 THEN 'Casey Williams'
        WHEN 5 THEN 'Morgan Brown'
        WHEN 6 THEN 'Taylor Kim'
        WHEN 7 THEN 'Jamie O''Connor'
    END AS PERFORMED_BY,
    DATEADD(HOUR, -1 * UNIFORM(1, 8760, RANDOM()), CURRENT_TIMESTAMP()) AS PERFORMED_AT,
    UNIFORM(15, 480, RANDOM()) AS DURATION_MINUTES,
    ROUND(UNIFORM(50.0, 12000.0, RANDOM())::FLOAT, 2) AS COST_USD,
    CASE WHEN UNIFORM(1, 10, RANDOM()) <= 4 THEN
        CASE MOD(SEQ4(), 6)
            WHEN 0 THEN 'Motor bearings, seals'
            WHEN 1 THEN 'Battery cells'
            WHEN 2 THEN 'Actuator assembly'
            WHEN 3 THEN 'Sensor module'
            WHEN 4 THEN 'Hydraulic hoses'
            WHEN 5 THEN 'Controller board'
        END
    ELSE NULL END AS PARTS_REPLACED,
    CASE MOD(SEQ4(), 4) WHEN 0 THEN 'Resolved' WHEN 1 THEN 'Resolved' WHEN 2 THEN 'Resolved' ELSE 'Monitoring' END AS OUTCOME,
    DATEADD(DAY, UNIFORM(14, 180, RANDOM()), CURRENT_DATE()) AS NEXT_SCHEDULED
FROM TABLE(GENERATOR(ROWCOUNT => 2000));

-- ============================================================================
-- INCIDENTS (500 incident records)
-- ============================================================================
INSERT INTO INCIDENTS
SELECT
    'INC-' || LPAD(SEQ4()::VARCHAR, 5, '0') AS INCIDENT_ID,
    'BOT-' || LPAD((MOD(SEQ4(), 200))::VARCHAR, 5, '0') AS ROBOT_ID,
    'DEP-' || LPAD((MOD(SEQ4(), 60))::VARCHAR, 4, '0') AS DEPLOYMENT_ID,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'Hardware Failure'
        WHEN 1 THEN 'Software Error'
        WHEN 2 THEN 'Communication Loss'
        WHEN 3 THEN 'Sensor Malfunction'
        WHEN 4 THEN 'Navigation Error'
        WHEN 5 THEN 'Battery Critical'
        WHEN 6 THEN 'Emergency Stop'
        WHEN 7 THEN 'Environmental Hazard'
    END AS INCIDENT_TYPE,
    CASE MOD(SEQ4(), 4) WHEN 0 THEN 'Critical' WHEN 1 THEN 'High' WHEN 2 THEN 'Medium' ELSE 'Low' END AS SEVERITY,
    CASE MOD(SEQ4(), 10)
        WHEN 0 THEN 'Motor overtemperature alarm triggered during heavy load operation. Robot entered safe mode automatically.'
        WHEN 1 THEN 'Navigation stack crash caused robot to halt. Restart required. Logs collected for analysis.'
        WHEN 2 THEN 'Lost 5G connectivity for 15 minutes in warehouse zone B. Robot operated in offline mode.'
        WHEN 3 THEN 'LiDAR returned inconsistent point cloud data. Obstacle detection compromised temporarily.'
        WHEN 4 THEN 'Path planning failure at warehouse intersection. Robot unable to navigate around dynamic obstacle.'
        WHEN 5 THEN 'Battery dropped below 8% with no charging station in range. Emergency retrieval required.'
        WHEN 6 THEN 'E-stop triggered by human operator during close-proximity operation. Safety protocol activated.'
        WHEN 7 THEN 'Water ingress detected in outdoor deployment during heavy rain. Sealed compartments held.'
        WHEN 8 THEN 'Joint actuator exceeded torque limits during object manipulation. Gripper released payload safely.'
        WHEN 9 THEN 'Firmware update interrupted by power fluctuation. Recovery mode initiated successfully.'
    END AS DESCRIPTION,
    DATEADD(HOUR, -1 * UNIFORM(1, 2160, RANDOM()), CURRENT_TIMESTAMP()) AS REPORTED_AT,
    CASE WHEN UNIFORM(1, 10, RANDOM()) <= 8
        THEN DATEADD(MINUTE, UNIFORM(15, 1440, RANDOM()), DATEADD(HOUR, -1 * UNIFORM(1, 2160, RANDOM()), CURRENT_TIMESTAMP()))
        ELSE NULL 
    END AS RESOLVED_AT,
    CASE WHEN UNIFORM(1, 10, RANDOM()) <= 8 THEN
        CASE MOD(SEQ4(), 6)
            WHEN 0 THEN 'Component replaced and system recalibrated'
            WHEN 1 THEN 'Software patched and functionality restored'
            WHEN 2 THEN 'Network equipment reset and signal boosted'
            WHEN 3 THEN 'Sensor recalibrated and validated against reference'
            WHEN 4 THEN 'Map updated and navigation retested successfully'
            WHEN 5 THEN 'Battery replaced and charging protocol reviewed'
        END
    ELSE NULL END AS RESOLUTION,
    CASE MOD(SEQ4(), 7)
        WHEN 0 THEN 'Component wear'
        WHEN 1 THEN 'Software bug'
        WHEN 2 THEN 'Network infrastructure'
        WHEN 3 THEN 'Environmental conditions'
        WHEN 4 THEN 'Calibration drift'
        WHEN 5 THEN 'Power supply fluctuation'
        WHEN 6 THEN 'Operator error'
    END AS ROOT_CAUSE,
    UNIFORM(5, 720, RANDOM()) AS DOWNTIME_MINUTES
FROM TABLE(GENERATOR(ROWCOUNT => 500));

-- ============================================================================
-- KNOWLEDGE_BASE (80 articles covering all robot models)
-- ============================================================================
INSERT INTO KNOWLEDGE_BASE
SELECT
    'KB-' || LPAD(SEQ4()::VARCHAR, 4, '0') AS ARTICLE_ID,
    TITLE,
    CATEGORY,
    SUBCATEGORY,
    CONTENT,
    ROBOT_MODEL,
    TAGS,
    AUTHOR,
    DATEADD(DAY, -1 * UNIFORM(1, 365, RANDOM()), CURRENT_TIMESTAMP()) AS CREATED_AT,
    CURRENT_TIMESTAMP() AS UPDATED_AT
FROM (
    SELECT SEQ4() AS RN,
    CASE MOD(SEQ4(), 80)
        WHEN 0 THEN 'Atlas Humanoid Robot Overview and Specifications'
        WHEN 1 THEN 'Spot Quadruped Robot Technical Specifications'
        WHEN 2 THEN 'Stretch Warehouse Robot Capabilities'
        WHEN 3 THEN 'Atlas Joint Calibration Procedure'
        WHEN 4 THEN 'Spot Autonomous Navigation Setup Guide'
        WHEN 5 THEN 'Stretch Gripper Maintenance Protocol'
        WHEN 6 THEN 'Battery Management Best Practices for Atlas'
        WHEN 7 THEN 'Spot Payload Integration Guidelines'
        WHEN 8 THEN 'Stretch Case Handling Optimization'
        WHEN 9 THEN 'Atlas Balance Control System Architecture'
        WHEN 10 THEN 'Spot Sensor Array Configuration'
        WHEN 11 THEN 'Stretch Vision System Calibration'
        WHEN 12 THEN 'Motor Overheating Troubleshooting Guide'
        WHEN 13 THEN 'Communication Module Recovery Procedures'
        WHEN 14 THEN 'Emergency Stop Protocol and Safety Guidelines'
        WHEN 15 THEN 'Atlas Firmware Update Procedures v3.x'
        WHEN 16 THEN 'Spot Firmware Update Procedures v4.x'
        WHEN 17 THEN 'Stretch Firmware Update Procedures v2.x'
        WHEN 18 THEN 'Hydraulic System Maintenance for Atlas'
        WHEN 19 THEN 'Spot Leg Mechanism Inspection Checklist'
        WHEN 20 THEN 'Stretch Conveyor Interface Setup'
        WHEN 21 THEN 'LiDAR Calibration and Accuracy Verification'
        WHEN 22 THEN 'Battery Cell Replacement Safety Protocol'
        WHEN 23 THEN 'Outdoor Deployment Weather Protection Guide'
        WHEN 24 THEN 'Atlas Dynamic Walking Algorithm Overview'
        WHEN 25 THEN 'Spot Stair Climbing Capability Configuration'
        WHEN 26 THEN 'Stretch Pallet Depalletizing Workflow'
        WHEN 27 THEN 'Predictive Maintenance Sensor Thresholds'
        WHEN 28 THEN 'Robot-to-Cloud Data Pipeline Architecture'
        WHEN 29 THEN 'Safety Zone Configuration for Shared Workspaces'
        WHEN 30 THEN 'Atlas Object Manipulation and Grasping Guide'
        WHEN 31 THEN 'Spot Thermal Imaging Inspection Module'
        WHEN 32 THEN 'Stretch Multi-SKU Sorting Configuration'
        WHEN 33 THEN 'Controller Board Diagnostics and Replacement'
        WHEN 34 THEN 'Network Connectivity Troubleshooting Guide'
        WHEN 35 THEN 'Robot Fleet Management Best Practices'
        WHEN 36 THEN 'Atlas Power System Architecture'
        WHEN 37 THEN 'Spot GPS and RTK Navigation Setup'
        WHEN 38 THEN 'Stretch Warehouse Mapping Procedures'
        WHEN 39 THEN 'Vibration Analysis and Motor Health Monitoring'
        WHEN 40 THEN 'Atlas Humanoid Ergonomics and Workspace Design'
        WHEN 41 THEN 'Spot Remote Operation Interface Guide'
        WHEN 42 THEN 'Stretch Throughput Optimization Techniques'
        WHEN 43 THEN 'Sensor Fusion Pipeline Technical Reference'
        WHEN 44 THEN 'Robot Operating System (ROS) Integration'
        WHEN 45 THEN 'API Reference for Telemetry Data Access'
        WHEN 46 THEN 'Atlas Knee Joint Actuator Service Manual'
        WHEN 47 THEN 'Spot Camera System Maintenance'
        WHEN 48 THEN 'Stretch Vacuum Gripper Troubleshooting'
        WHEN 49 THEN 'Environmental Certification and Compliance Guide'
        WHEN 50 THEN 'Atlas All-Electric Drive System Overview'
        WHEN 51 THEN 'Spot Autonomous Charging Station Integration'
        WHEN 52 THEN 'Stretch Inventory Tracking System'
        WHEN 53 THEN 'Joint Actuator Torque Calibration Procedure'
        WHEN 54 THEN 'Cybersecurity Best Practices for Robot Fleet'
        WHEN 55 THEN 'Over-the-Air Update Deployment Guide'
        WHEN 56 THEN 'Atlas Hip Joint Rehabilitation Protocol'
        WHEN 57 THEN 'Spot Terrain Adaptation Parameters'
        WHEN 58 THEN 'Stretch Error Code Reference Manual'
        WHEN 59 THEN 'Robot Decommissioning and Data Wipe Procedures'
        WHEN 60 THEN 'Atlas Full Body Motion Planning'
        WHEN 61 THEN 'Spot Confined Space Inspection Protocol'
        WHEN 62 THEN 'Stretch Loading Dock Interface Guide'
        WHEN 63 THEN 'Preventive Maintenance Schedule Templates'
        WHEN 64 THEN 'Component Lifetime Estimation Methods'
        WHEN 65 THEN 'Fleet Dashboard Configuration Guide'
        WHEN 66 THEN 'Atlas Shoulder Actuator Replacement'
        WHEN 67 THEN 'Spot Hazardous Area Deployment Guide'
        WHEN 68 THEN 'Stretch Cold Storage Operation Guidelines'
        WHEN 69 THEN 'Incident Response and Escalation Procedures'
        WHEN 70 THEN 'Atlas Bipedal Locomotion Research Notes'
        WHEN 71 THEN 'Spot Industrial Inspection Workflow Templates'
        WHEN 72 THEN 'Stretch Performance Benchmarking Guide'
        WHEN 73 THEN 'Robot Insurance and Liability Guidelines'
        WHEN 74 THEN 'Multi-Robot Coordination Protocol'
        WHEN 75 THEN 'Atlas Wrist Joint Precision Tuning'
        WHEN 76 THEN 'Spot Payload Weight Distribution Guide'
        WHEN 77 THEN 'Stretch Case Dimension Recognition Setup'
        WHEN 78 THEN 'Warranty Terms and Service Level Agreements'
        WHEN 79 THEN 'Boston Dynamics Customer Support Escalation Matrix'
    END AS TITLE,
    CASE
        WHEN MOD(SEQ4(), 80) IN (0,1,2,9,10,11,24,25,26,30,31,32,40,41,42,50,51,52,60,61,62,70,71,72) THEN 'Product Specifications'
        WHEN MOD(SEQ4(), 80) IN (3,4,5,8,19,20,21,37,38,43,44,45,53,57) THEN 'Technical Procedures'
        WHEN MOD(SEQ4(), 80) IN (6,7,15,16,17,18,22,27,33,39,46,47,48,55,56,63,64,66,75) THEN 'Maintenance'
        WHEN MOD(SEQ4(), 80) IN (12,13,14,34,58,69,79) THEN 'Troubleshooting'
        WHEN MOD(SEQ4(), 80) IN (23,29,49,54,59,67,68,73,78) THEN 'Safety & Compliance'
        ELSE 'Operations'
    END AS CATEGORY,
    CASE
        WHEN MOD(SEQ4(), 80) < 3 THEN 'Product Overview'
        WHEN MOD(SEQ4(), 80) < 12 THEN 'Configuration'
        WHEN MOD(SEQ4(), 80) < 20 THEN 'Repair & Service'
        WHEN MOD(SEQ4(), 80) < 30 THEN 'Setup & Integration'
        WHEN MOD(SEQ4(), 80) < 45 THEN 'Advanced Operations'
        WHEN MOD(SEQ4(), 80) < 55 THEN 'System Reference'
        WHEN MOD(SEQ4(), 80) < 65 THEN 'Service Manuals'
        WHEN MOD(SEQ4(), 80) < 75 THEN 'Deployment Guides'
        ELSE 'Administration'
    END AS SUBCATEGORY,
    CASE MOD(SEQ4(), 80)
        WHEN 0 THEN 'Atlas is the world most dynamic humanoid robot, designed for a wide range of manipulation and mobility tasks. The all-electric Atlas stands 1.5 meters tall, weighs approximately 89 kg, and features 28 degrees of freedom for full-body dexterity. Atlas is powered by a high-voltage electric drive system with custom actuators delivering exceptional power density. Key capabilities include bipedal walking on uneven terrain, object manipulation with precision grippers, dynamic balance recovery, and autonomous navigation. Atlas is designed for commercial deployment in manufacturing, logistics, and service environments where human-like mobility is required.'
        WHEN 1 THEN 'Spot is a nimble quadruped robot designed for autonomous sensing in dynamic environments. Spot weighs 32 kg, stands 0.84 meters tall, and can carry up to 14 kg of payload. With a top speed of 1.6 m/s, Spot navigates stairs, rough terrain, and indoor environments autonomously. The robot features 12 degrees of freedom across four legs, a 360-degree perception system with stereo cameras, and optional payloads including thermal cameras, LiDAR, and gas detection sensors. Spot operates for approximately 90 minutes on a single charge and supports autonomous missions via the Spot SDK.'
        WHEN 2 THEN 'Stretch is a purpose-built mobile robot designed for warehouse automation, specifically case handling and truck unloading. Stretch features a mobile base for omnidirectional movement, a perception system for box detection, and a custom gripper capable of handling cases up to 23 kg. The robot can process up to 800 cases per hour and adapts to varying case sizes and weights. Stretch integrates with warehouse management systems via standard APIs and operates autonomously after initial configuration.'
        ELSE 'This article provides detailed technical information about Boston Dynamics robot systems. It covers specifications, operational procedures, maintenance protocols, troubleshooting guides, and best practices for deployment and fleet management. Content is regularly updated to reflect the latest firmware releases and operational improvements. For the most current information, consult the Boston Dynamics technical support portal or contact your designated field service engineer. All procedures described here assume proper safety training has been completed and appropriate personal protective equipment is available. Follow all local regulations and site-specific safety requirements when performing any maintenance or operational procedures on Boston Dynamics robots.'
    END AS CONTENT,
    CASE
        WHEN MOD(SEQ4(), 80) IN (0,3,6,9,15,18,24,30,36,40,46,50,56,60,66,70,75) THEN 'Atlas'
        WHEN MOD(SEQ4(), 80) IN (1,4,7,10,16,19,25,31,37,41,47,51,57,61,67,71,76) THEN 'Spot'
        WHEN MOD(SEQ4(), 80) IN (2,5,8,11,17,20,26,32,38,42,48,52,58,62,68,72,77) THEN 'Stretch'
        ELSE 'All Models'
    END AS ROBOT_MODEL,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'maintenance,hardware,inspection'
        WHEN 1 THEN 'software,firmware,configuration'
        WHEN 2 THEN 'safety,compliance,operations'
        WHEN 3 THEN 'telemetry,sensors,diagnostics'
        WHEN 4 THEN 'deployment,setup,integration'
        WHEN 5 THEN 'troubleshooting,repair,support'
    END AS TAGS,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'Dr. Sarah Kim, Robotics Engineering'
        WHEN 1 THEN 'Michael Chen, Field Service'
        WHEN 2 THEN 'Emma Watson, Safety Engineering'
        WHEN 3 THEN 'Robert Playter, CTO Office'
        WHEN 4 THEN 'Lisa Park, Product Documentation'
    END AS AUTHOR
    FROM TABLE(GENERATOR(ROWCOUNT => 80))
);

-- ============================================================================
-- FIRMWARE_RELEASES (30 firmware releases)
-- ============================================================================
INSERT INTO FIRMWARE_RELEASES
SELECT
    'FW-' || LPAD(SEQ4()::VARCHAR, 4, '0') AS RELEASE_ID,
    CASE MOD(SEQ4(), 3)
        WHEN 0 THEN '3.' || (MOD(SEQ4(), 10) + 1)::VARCHAR || '.' || MOD(SEQ4(), 20)::VARCHAR
        WHEN 1 THEN '4.' || (MOD(SEQ4(), 10) + 1)::VARCHAR || '.' || MOD(SEQ4(), 20)::VARCHAR
        ELSE '2.' || (MOD(SEQ4(), 10) + 1)::VARCHAR || '.' || MOD(SEQ4(), 20)::VARCHAR
    END AS VERSION,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'Atlas' WHEN 1 THEN 'Spot' ELSE 'Stretch' END AS ROBOT_MODEL,
    DATEADD(DAY, -1 * UNIFORM(1, 730, RANDOM()), CURRENT_DATE()) AS RELEASE_DATE,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'Improved motor temperature management and thermal throttling algorithms'
        WHEN 1 THEN 'Enhanced autonomous navigation with better obstacle avoidance'
        WHEN 2 THEN 'Battery management optimization for extended runtime'
        WHEN 3 THEN 'Critical security patches and communication encryption updates'
        WHEN 4 THEN 'New manipulation algorithms for improved gripper precision'
        WHEN 5 THEN 'Sensor fusion improvements for better environmental awareness'
    END AS RELEASE_NOTES,
    CASE WHEN MOD(SEQ4(), 5) = 0 THEN TRUE ELSE FALSE END AS IS_CRITICAL,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 'Motor Controller, Safety System'
        WHEN 1 THEN 'Navigation Stack, LiDAR Driver'
        WHEN 2 THEN 'Battery Management, Power Distribution'
        WHEN 3 THEN 'Communication Module, Encryption Engine'
    END AS AFFECTED_COMPONENTS
FROM TABLE(GENERATOR(ROWCOUNT => 30));
