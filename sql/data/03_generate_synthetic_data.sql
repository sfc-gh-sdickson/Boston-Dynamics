/*=============================================================================
  Boston Dynamics Intelligence Agent
  Step 3: Synthetic Data Generation

  Execution Order: 3 of 9
  Description: Generates correlated synthetic data for fleet operations and
               Customer 360. Each of the 100 customers is assigned a hidden
               profile (HEALTHY / EXPANDING / AT_RISK / CHURNED) that drives
               usage, NPS, tickets, invoices, incidents, sentiment and
               renewals, so the ML models have real signal to learn.
               Safe to re-run: every table is truncated first.
               Run the whole file in ONE session (uses temporary tables).
=============================================================================*/

USE DATABASE BD_INTELLIGENCE;
USE SCHEMA RAW;
USE WAREHOUSE BOSTON_DYNAMICS_WH;

TRUNCATE TABLE IF EXISTS CUSTOMERS;
TRUNCATE TABLE IF EXISTS DEPLOYMENTS;
TRUNCATE TABLE IF EXISTS ROBOTS;
TRUNCATE TABLE IF EXISTS COMPONENTS;
TRUNCATE TABLE IF EXISTS ROBOT_TELEMETRY;
TRUNCATE TABLE IF EXISTS MAINTENANCE_RECORDS;
TRUNCATE TABLE IF EXISTS INCIDENTS;
TRUNCATE TABLE IF EXISTS KNOWLEDGE_BASE;
TRUNCATE TABLE IF EXISTS FIRMWARE_RELEASES;
TRUNCATE TABLE IF EXISTS CONTACTS;
TRUNCATE TABLE IF EXISTS CONTRACTS;
TRUNCATE TABLE IF EXISTS INVOICES;
TRUNCATE TABLE IF EXISTS SUPPORT_TICKETS;
TRUNCATE TABLE IF EXISTS SURVEYS;
TRUNCATE TABLE IF EXISTS PRODUCT_USAGE_DAILY;
TRUNCATE TABLE IF EXISTS OPPORTUNITIES;
TRUNCATE TABLE IF EXISTS INTERACTIONS;

-- ============================================================================
-- CUSTOMER SEED (100 customers) and hidden PROFILE
-- Industry codes: AUTO, LOGI, ENRG, AERO, MINE, INDU
-- ============================================================================
CREATE OR REPLACE TEMPORARY TABLE _CUST_SEED AS
SELECT column1::INT AS N, column2::VARCHAR AS CUSTOMER_NAME, column3::VARCHAR AS IND,
       column4::VARCHAR AS COUNTRY, column5::VARCHAR AS HQ_CITY,
       column6::FLOAT AS LAT, column7::FLOAT AS LON
FROM VALUES
 (0,'Tesla Gigafactory','AUTO','United States','Austin',30.27,-97.74),
 (1,'Amazon Fulfillment','LOGI','United States','Seattle',47.61,-122.33),
 (2,'Shell Energy','ENRG','United Kingdom','London',51.51,-0.13),
 (3,'Chevron Refinery','ENRG','United States','Houston',29.76,-95.37),
 (4,'US Army Corps','AERO','United States','Washington',38.90,-77.04),
 (5,'NASA JPL','AERO','United States','Pasadena',34.15,-118.14),
 (6,'Toyota Manufacturing','AUTO','Japan','Toyota City',35.08,137.16),
 (7,'Samsung Electronics','INDU','South Korea','Suwon',37.26,127.03),
 (8,'DHL Logistics','LOGI','Germany','Bonn',50.74,7.10),
 (9,'BP Energy','ENRG','United Kingdom','London',51.51,-0.13),
 (10,'Ford Motor Company','AUTO','United States','Dearborn',42.32,-83.18),
 (11,'Caterpillar Inc','INDU','United States','Irving',32.81,-96.95),
 (12,'Rio Tinto Mining','MINE','Australia','Perth',-31.95,115.86),
 (13,'Lockheed Martin','AERO','United States','Bethesda',38.98,-77.10),
 (14,'Procter and Gamble','INDU','United States','Cincinnati',39.10,-84.51),
 (15,'Walmart Distribution','LOGI','United States','Bentonville',36.37,-94.21),
 (16,'General Electric','INDU','United States','Boston',42.36,-71.06),
 (17,'Siemens Energy','ENRG','Germany','Munich',48.14,11.58),
 (18,'Vale Mining','MINE','Brazil','Rio de Janeiro',-22.91,-43.17),
 (19,'FedEx Ground','LOGI','United States','Memphis',35.15,-90.05),
 (20,'BMW Manufacturing','AUTO','Germany','Munich',48.14,11.58),
 (21,'Dow Chemical','INDU','United States','Midland',43.62,-84.25),
 (22,'BHP Group Mining','MINE','Australia','Melbourne',-37.81,144.96),
 (23,'Northrop Grumman','AERO','United States','Falls Church',38.88,-77.17),
 (24,'Johnson and Johnson','INDU','United States','New Brunswick',40.49,-74.45),
 (25,'Target Distribution','LOGI','United States','Minneapolis',44.98,-93.27),
 (26,'Honeywell Aerospace','AERO','United States','Phoenix',33.45,-112.07),
 (27,'Duke Energy','ENRG','United States','Charlotte',35.23,-80.84),
 (28,'Anglo American Mining','MINE','South Africa','Johannesburg',-26.20,28.05),
 (29,'SpaceX','AERO','United States','Hawthorne',33.92,-118.35),
 (30,'Hyundai Motor Group','AUTO','South Korea','Seoul',37.57,126.98),
 (31,'General Motors','AUTO','United States','Detroit',42.33,-83.05),
 (32,'Volkswagen Group','AUTO','Germany','Wolfsburg',52.42,10.79),
 (33,'Honda Manufacturing','AUTO','Japan','Tokyo',35.68,139.69),
 (34,'Stellantis','AUTO','Netherlands','Amsterdam',52.37,4.90),
 (35,'Mercedes-Benz Plants','AUTO','Germany','Stuttgart',48.78,9.18),
 (36,'Nissan Assembly','AUTO','Japan','Yokohama',35.44,139.64),
 (37,'Rivian Automotive','AUTO','United States','Irvine',33.68,-117.83),
 (38,'Kia Manufacturing','AUTO','United States','West Point',32.88,-85.18),
 (39,'Volvo Cars','AUTO','Sweden','Gothenburg',57.71,11.97),
 (40,'Magna International','AUTO','Canada','Aurora',44.00,-79.45),
 (41,'Bosch Automotive','AUTO','Germany','Stuttgart',48.78,9.18),
 (42,'Denso Corporation','AUTO','Japan','Kariya',34.99,137.00),
 (43,'UPS Supply Chain','LOGI','United States','Atlanta',33.75,-84.39),
 (44,'Maersk Logistics','LOGI','Denmark','Copenhagen',55.68,12.57),
 (45,'GXO Logistics','LOGI','United States','Greenwich',41.03,-73.63),
 (46,'Kuehne Nagel','LOGI','Switzerland','Schindellegi',47.17,8.71),
 (47,'XPO Logistics','LOGI','United States','Greenwich',41.03,-73.63),
 (48,'Ocado Group','LOGI','United Kingdom','Hatfield',51.76,-0.23),
 (49,'JD Logistics','LOGI','China','Beijing',39.90,116.41),
 (50,'Kroger Distribution','LOGI','United States','Cincinnati',39.10,-84.51),
 (51,'Home Depot Supply Chain','LOGI','United States','Atlanta',33.75,-84.39),
 (52,'Costco Logistics','LOGI','United States','Issaquah',47.53,-122.03),
 (53,'Zalando Fulfillment','LOGI','Germany','Berlin',52.52,13.40),
 (54,'Otto Group Logistics','LOGI','Germany','Hamburg',53.55,9.99),
 (55,'ExxonMobil','ENRG','United States','Spring',30.08,-95.42),
 (56,'TotalEnergies','ENRG','France','Paris',48.86,2.35),
 (57,'Equinor','ENRG','Norway','Stavanger',58.97,5.73),
 (58,'National Grid','ENRG','United Kingdom','Warwick',52.28,-1.58),
 (59,'Enel Group','ENRG','Italy','Rome',41.90,12.50),
 (60,'Iberdrola','ENRG','Spain','Bilbao',43.26,-2.93),
 (61,'ConocoPhillips','ENRG','United States','Houston',29.76,-95.37),
 (62,'Petrobras','ENRG','Brazil','Rio de Janeiro',-22.91,-43.17),
 (63,'Saudi Aramco','ENRG','Saudi Arabia','Dhahran',26.29,50.11),
 (64,'Ontario Power Generation','ENRG','Canada','Toronto',43.65,-79.38),
 (65,'Dominion Energy','ENRG','United States','Richmond',37.54,-77.44),
 (66,'NextEra Energy','ENRG','United States','Juno Beach',26.88,-80.06),
 (67,'Boeing Defense','AERO','United States','Arlington',38.88,-77.10),
 (68,'Raytheon Technologies','AERO','United States','Arlington',38.88,-77.10),
 (69,'Airbus','AERO','France','Toulouse',43.60,1.44),
 (70,'BAE Systems','AERO','United Kingdom','Farnborough',51.29,-0.75),
 (71,'General Dynamics','AERO','United States','Reston',38.96,-77.36),
 (72,'Rolls-Royce Aerospace','AERO','United Kingdom','Derby',52.92,-1.48),
 (73,'Safran Group','AERO','France','Paris',48.86,2.35),
 (74,'L3Harris','AERO','United States','Melbourne',28.08,-80.61),
 (75,'Blue Origin','AERO','United States','Kent',47.38,-122.23),
 (76,'Thales Group','AERO','France','Paris',48.86,2.35),
 (77,'Embraer','AERO','Brazil','Sao Jose dos Campos',-23.18,-45.88),
 (78,'Glencore','MINE','Switzerland','Baar',47.20,8.53),
 (79,'Freeport-McMoRan','MINE','United States','Phoenix',33.45,-112.07),
 (80,'Newmont','MINE','United States','Denver',39.74,-104.99),
 (81,'Barrick Gold','MINE','Canada','Toronto',43.65,-79.38),
 (82,'Teck Resources','MINE','Canada','Vancouver',49.28,-123.12),
 (83,'Fortescue Metals','MINE','Australia','Perth',-31.95,115.86),
 (84,'Codelco','MINE','Chile','Santiago',-33.45,-70.67),
 (85,'Antofagasta Minerals','MINE','Chile','Santiago',-33.45,-70.67),
 (86,'Southern Copper','MINE','Peru','Lima',-12.05,-77.04),
 (87,'Agnico Eagle','MINE','Canada','Toronto',43.65,-79.38),
 (88,'Newcrest Mining','MINE','Australia','Melbourne',-37.81,144.96),
 (89,'Kinross Gold','MINE','Canada','Toronto',43.65,-79.38),
 (90,'3M Company','INDU','United States','Saint Paul',44.95,-93.09),
 (91,'BASF','INDU','Germany','Ludwigshafen',49.48,8.44),
 (92,'Pfizer Manufacturing','INDU','United States','New York',40.71,-74.01),
 (93,'Nestle Operations','INDU','Switzerland','Vevey',46.46,6.84),
 (94,'Unilever Manufacturing','INDU','United Kingdom','London',51.51,-0.13),
 (95,'Schneider Electric','INDU','France','Rueil-Malmaison',48.88,2.18),
 (96,'Emerson Electric','INDU','United States','Saint Louis',38.63,-90.20),
 (97,'DuPont','INDU','United States','Wilmington',39.74,-75.55),
 (98,'John Deere','INDU','United States','Moline',41.51,-90.52),
 (99,'ABB Group','INDU','Switzerland','Zurich',47.38,8.54);

-- Hidden profile: 60 HEALTHY, 20 EXPANDING, 10 AT_RISK, 10 CHURNED.
-- CUTOFF_TS = last date of activity (churn date for churned, now otherwise).
-- RECENCY_EXP > 1 concentrates events near the cutoff (deteriorating accounts).
CREATE OR REPLACE TEMPORARY TABLE _CUST_PROFILE AS
SELECT
    N,
    'CUST-' || LPAD(N::VARCHAR, 4, '0') AS CUSTOMER_ID,
    PROFILE,
    CHURN_DATE,
    COALESCE(CHURN_DATE::TIMESTAMP_NTZ, CURRENT_TIMESTAMP()::TIMESTAMP_NTZ) AS CUTOFF_TS,
    CASE PROFILE WHEN 'AT_RISK' THEN 2.0 WHEN 'CHURNED' THEN 1.8 ELSE 1.0 END AS RECENCY_EXP
FROM (
    SELECT N, PROFILE,
        CASE WHEN PROFILE = 'CHURNED' THEN DATEADD(DAY, -1 * UNIFORM(45, 200, RANDOM()), CURRENT_DATE()) END AS CHURN_DATE
    FROM (
        SELECT N,
            CASE WHEN MOD(N, 10) = 3 THEN 'CHURNED'
                 WHEN MOD(N, 10) = 7 THEN 'AT_RISK'
                 WHEN MOD(N, 10) IN (1, 5) THEN 'EXPANDING'
                 ELSE 'HEALTHY' END AS PROFILE
        FROM _CUST_SEED
    )
);

-- ============================================================================
-- CUSTOMERS (100)
-- ============================================================================
INSERT INTO CUSTOMERS
SELECT
    p.CUSTOMER_ID,
    s.CUSTOMER_NAME,
    CASE s.IND WHEN 'AUTO' THEN 'Automotive Manufacturing' WHEN 'LOGI' THEN 'Logistics & Warehousing'
               WHEN 'ENRG' THEN 'Energy & Utilities' WHEN 'AERO' THEN 'Aerospace & Defense'
               WHEN 'MINE' THEN 'Mining & Resources' ELSE 'Industrial Manufacturing' END AS INDUSTRY,
    CASE WHEN x.REV >= 100000000000 THEN 'Enterprise' WHEN x.REV >= 20000000000 THEN 'Large' ELSE 'Mid-Market' END AS COMPANY_SIZE,
    CASE WHEN s.COUNTRY IN ('United States','Canada') THEN 'North America'
         WHEN s.COUNTRY IN ('Brazil','Chile','Peru') THEN 'South America'
         WHEN s.COUNTRY IN ('Japan','South Korea','China','Australia') THEN 'Asia Pacific'
         WHEN s.COUNTRY IN ('Saudi Arabia','South Africa') THEN 'Middle East & Africa'
         ELSE 'Europe' END AS REGION,
    s.COUNTRY,
    NULL AS CONTRACT_START_DATE,   -- set from CONTRACTS below
    NULL AS CONTRACT_END_DATE,
    GET(ARRAY_CONSTRUCT('Sarah Chen','Marcus Johnson','Elena Rodriguez','James Park','Priya Patel','David Thompson'), MOD(s.N, 6))::VARCHAR AS ACCOUNT_MANAGER,
    CASE WHEN x.REV >= 100000000000 THEN 'Platinum' WHEN x.REV >= 40000000000 THEN 'Gold'
         WHEN x.REV >= 10000000000 THEN 'Silver' ELSE 'Bronze' END AS SUPPORT_TIER,
    CASE WHEN x.REV >= 100000000000 THEN 'Strategic' WHEN x.REV >= 20000000000 THEN 'Enterprise' ELSE 'Commercial' END AS SEGMENT,
    x.REV AS ANNUAL_REVENUE_USD,
    ROUND(x.REV / UNIFORM(250000, 600000, RANDOM()))::INT AS EMPLOYEE_COUNT,
    DATEADD(DAY, -1 * UNIFORM(420, 1800, RANDOM()), p.CUTOFF_TS::DATE) AS CUSTOMER_SINCE,
    GET(ARRAY_CONSTRUCT('Nina Alvarez','Tom Becker','Grace Liu','Omar Haddad','Rachel Green','Ben Okafor','Hannah Mueller','Luis Romero'), MOD(s.N, 8))::VARCHAR AS CSM_NAME,
    s.HQ_CITY,
    NULL AS LIFECYCLE_STAGE        -- set below
FROM _CUST_SEED s
JOIN _CUST_PROFILE p ON p.N = s.N
JOIN (SELECT N, ROUND(EXP(UNIFORM(21.4::FLOAT, 26.7::FLOAT, RANDOM())), -6) AS REV FROM _CUST_SEED) x ON x.N = s.N;

-- ============================================================================
-- DEPLOYMENTS (200 sites, 2 per customer, located near customer HQ)
-- ============================================================================
INSERT INTO DEPLOYMENTS
SELECT
    'DEP-' || LPAD(g.I::VARCHAR, 4, '0') AS DEPLOYMENT_ID,
    p.CUSTOMER_ID,
    GET(ARRAY_CONSTRUCT('Assembly Line Alpha','Warehouse Zone B','Offshore Platform 7','Refinery Section C',
        'Test Range Delta','Clean Room 12','Paint Shop East','Fabrication Hall','Distribution Hub 3',
        'Pipeline Inspection','Production Floor Main','Underground Level 2','Open Pit Section A',
        'Hangar Bay 4','Packaging Center','Cold Storage Wing','Turbine Hall','Substation Grid',
        'Mine Shaft 3','Sorting Facility'), MOD(g.I, 20))::VARCHAR || ' - ' || s.HQ_CITY || ' ' || (FLOOR(g.I / 100) + 1)::VARCHAR AS SITE_NAME,
    CASE s.IND WHEN 'AUTO' THEN 'Manufacturing Floor' WHEN 'LOGI' THEN 'Warehouse'
               WHEN 'ENRG' THEN IFF(MOD(g.I, 2) = 0, 'Outdoor Industrial', 'Hazardous Area')
               WHEN 'MINE' THEN 'Underground' WHEN 'AERO' THEN 'Laboratory' ELSE 'Manufacturing Floor' END AS SITE_TYPE,
    DATEADD(DAY, UNIFORM(0, 120, RANDOM()), c.CUSTOMER_SINCE) AS DEPLOYMENT_DATE,
    0 AS ROBOT_COUNT,              -- set from ROBOTS below
    CASE s.IND WHEN 'AUTO' THEN IFF(MOD(g.I, 2) = 0, 'Material Handling', 'Quality Assurance')
               WHEN 'LOGI' THEN IFF(MOD(g.I, 2) = 0, 'Truck Unloading', 'Inventory Management')
               WHEN 'ENRG' THEN IFF(MOD(g.I, 2) = 0, 'Autonomous Inspection', 'Hazardous Environment Inspection')
               WHEN 'MINE' THEN 'Remote Monitoring' WHEN 'AERO' THEN IFF(MOD(g.I, 2) = 0, 'Data Collection', 'Security Patrol')
               ELSE 'Autonomous Inspection' END AS PRIMARY_USE_CASE,
    CASE s.IND WHEN 'ENRG' THEN 'Hazardous' WHEN 'MINE' THEN 'Outdoor' WHEN 'LOGI' THEN 'Indoor' ELSE 'Mixed' END AS ENVIRONMENT,
    CASE WHEN p.PROFILE = 'CHURNED' THEN 'Decommissioned'
         WHEN UNIFORM(1, 10, RANDOM()) = 1 THEN 'Maintenance' ELSE 'Active' END AS STATUS,
    s.LAT + UNIFORM(-1.5::FLOAT, 1.5::FLOAT, RANDOM()) AS LATITUDE,
    s.LON + UNIFORM(-1.5::FLOAT, 1.5::FLOAT, RANDOM()) AS LONGITUDE
FROM (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS I FROM TABLE(GENERATOR(ROWCOUNT => 200))) g
JOIN _CUST_PROFILE p ON p.N = MOD(g.I, 100)
JOIN _CUST_SEED s ON s.N = p.N
JOIN CUSTOMERS c ON c.CUSTOMER_ID = p.CUSTOMER_ID;

-- ============================================================================
-- ROBOTS (600). Model mix depends on customer industry.
-- ============================================================================
INSERT INTO ROBOTS
SELECT
    'BOT-' || LPAD(g.I::VARCHAR, 5, '0') AS ROBOT_ID,
    g.MODEL || '-' || LPAD(g.I::VARCHAR, 3, '0') AS ROBOT_NAME,
    g.MODEL AS ROBOT_MODEL,
    'BD-' || UPPER(SUBSTR(MD5(g.I::VARCHAR), 1, 12)) AS SERIAL_NUMBER,
    DATEADD(DAY, -1 * UNIFORM(30, 180, RANDOM()), g.DEPLOYMENT_DATE) AS MANUFACTURE_DATE,
    CASE g.MODEL WHEN 'Atlas' THEN '3.' WHEN 'Spot' THEN '4.' ELSE '2.' END
        || UNIFORM(1, 9, RANDOM()) || '.' || UNIFORM(0, 20, RANDOM()) AS FIRMWARE_VERSION,
    CASE WHEN g.PROFILE = 'CHURNED' THEN 'Decommissioned'
         WHEN g.U < 0.75 THEN 'Active' WHEN g.U < 0.88 THEN 'Idle' WHEN g.U < 0.97 THEN 'Maintenance'
         ELSE 'Decommissioned' END AS STATUS,
    g.DEPLOYMENT_ID,
    CURRENT_TIMESTAMP() AS CREATED_AT,
    CURRENT_TIMESTAMP() AS UPDATED_AT
FROM (
    SELECT r.I, r.U, d.DEPLOYMENT_ID, d.DEPLOYMENT_DATE, p.PROFILE,
        CASE s.IND
            WHEN 'LOGI' THEN IFF(r.M < 0.75, 'Stretch', 'Spot')
            WHEN 'AUTO' THEN IFF(r.M < 0.50, 'Atlas', IFF(r.M < 0.80, 'Stretch', 'Spot'))
            WHEN 'INDU' THEN IFF(r.M < 0.35, 'Atlas', 'Spot')
            ELSE IFF(r.M < 0.15, 'Atlas', 'Spot') END AS MODEL
    FROM (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS I,
                 UNIFORM(0, 199, RANDOM()) AS DEP_IDX,
                 UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) AS U,
                 UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) AS M
          FROM TABLE(GENERATOR(ROWCOUNT => 600))) r
    JOIN DEPLOYMENTS d ON d.DEPLOYMENT_ID = 'DEP-' || LPAD(r.DEP_IDX::VARCHAR, 4, '0')
    JOIN _CUST_PROFILE p ON p.CUSTOMER_ID = d.CUSTOMER_ID
    JOIN _CUST_SEED s ON s.N = p.N
) g;

-- Fix: ROBOT_COUNT now reflects the robots actually assigned to each site
UPDATE DEPLOYMENTS d SET ROBOT_COUNT = COALESCE(x.CNT, 0)
FROM (SELECT d2.DEPLOYMENT_ID, COUNT(r.ROBOT_ID) AS CNT
      FROM DEPLOYMENTS d2 LEFT JOIN ROBOTS r ON r.DEPLOYMENT_ID = d2.DEPLOYMENT_ID
      GROUP BY d2.DEPLOYMENT_ID) x
WHERE x.DEPLOYMENT_ID = d.DEPLOYMENT_ID;

-- Robot context used by the event generators below
CREATE OR REPLACE TEMPORARY TABLE _ROBOT_CTX AS
SELECT
    TO_NUMBER(SUBSTR(r.ROBOT_ID, 5)) AS ROBOT_IDX,
    r.ROBOT_ID, r.ROBOT_MODEL, r.DEPLOYMENT_ID, d.CUSTOMER_ID,
    p.PROFILE, p.CUTOFF_TS, p.RECENCY_EXP
FROM ROBOTS r
JOIN DEPLOYMENTS d ON d.DEPLOYMENT_ID = r.DEPLOYMENT_ID
JOIN _CUST_PROFILE p ON p.CUSTOMER_ID = d.CUSTOMER_ID;

-- ============================================================================
-- COMPONENTS (3,000 = 5 per robot). Condition is driven by a hidden wear
-- index: age / lifespan scaled by duty cycle, plus stress on at-risk fleets,
-- plus noise. STATUS and INSPECTION_RUL_DAYS both derive from it.
-- ============================================================================
INSERT INTO COMPONENTS
SELECT
    w.COMPONENT_ID, w.ROBOT_ID, w.COMPONENT_TYPE, w.COMPONENT_NAME,
    DATEADD(DAY, -1 * w.AGE_DAYS, CURRENT_DATE()) AS INSTALL_DATE,
    w.LIFESPAN AS EXPECTED_LIFESPAN_DAYS,
    ROUND(w.AGE_DAYS * w.DUTY_HRS, 1) AS CURRENT_RUNTIME_HOURS,
    CASE WHEN w.WEAR < 0.60 THEN 'Operational'
         WHEN w.WEAR < 0.85 THEN 'Degraded'
         WHEN w.WEAR < 1.05 THEN 'Needs Replacement'
         ELSE 'Failed' END AS STATUS,
    w.LAST_INSPECTION_DATE,
    GREATEST(0, ROUND((1.05 - w.WEAR) / w.WEAR_PER_DAY))::INT AS INSPECTION_RUL_DAYS
FROM (
    SELECT v.*,
        v.WEAR_PER_DAY * v.AGE_DAYS + v.STRESS + v.NOISE AS WEAR
    FROM (
        SELECT
            'COMP-' || LPAD(g.I::VARCHAR, 5, '0') AS COMPONENT_ID,
            rc.ROBOT_ID,
            GET(ARRAY_CONSTRUCT('Motor','Battery','Sensor','Joint Actuator','Camera','LiDAR','Gripper',
                'Communication Module','Controller Board','Hydraulic Pump'), g.T)::VARCHAR AS COMPONENT_TYPE,
            CASE g.T
                WHEN 0 THEN GET(ARRAY_CONSTRUCT('Hip Motor','Knee Motor','Shoulder Motor'), MOD(g.I, 3))::VARCHAR
                WHEN 1 THEN GET(ARRAY_CONSTRUCT('Primary Battery Pack','Auxiliary Battery'), MOD(g.I, 2))::VARCHAR
                WHEN 2 THEN GET(ARRAY_CONSTRUCT('Temperature Sensor','Vibration Sensor','Force Torque Sensor'), MOD(g.I, 3))::VARCHAR
                WHEN 3 THEN GET(ARRAY_CONSTRUCT('Elbow Actuator','Wrist Actuator','Ankle Actuator'), MOD(g.I, 3))::VARCHAR
                WHEN 4 THEN GET(ARRAY_CONSTRUCT('Stereo Camera','Depth Camera'), MOD(g.I, 2))::VARCHAR
                WHEN 5 THEN 'Velodyne LiDAR Unit'
                WHEN 6 THEN GET(ARRAY_CONSTRUCT('Precision Gripper','Vacuum Gripper'), MOD(g.I, 2))::VARCHAR
                WHEN 7 THEN GET(ARRAY_CONSTRUCT('5G Radio Module','WiFi 6E Module'), MOD(g.I, 2))::VARCHAR
                WHEN 8 THEN GET(ARRAY_CONSTRUCT('Main Controller','Safety Controller'), MOD(g.I, 2))::VARCHAR
                ELSE 'Hydraulic Power Unit' END AS COMPONENT_NAME,
            g.AGE_DAYS,
            g.LIFESPAN,
            g.DUTY_HRS,
            (g.DUTY_HRS / 12.0) / g.LIFESPAN AS WEAR_PER_DAY,
            IFF(rc.PROFILE IN ('AT_RISK','CHURNED'), 0.20, 0.0) AS STRESS,
            g.NOISE,
            DATEADD(DAY, -1 * UNIFORM(1, 90, RANDOM()), CURRENT_DATE()) AS LAST_INSPECTION_DATE
        FROM (
            SELECT h.*,
                CASE h.T WHEN 0 THEN UNIFORM(500, 1500, RANDOM()) WHEN 1 THEN UNIFORM(365, 730, RANDOM())
                         WHEN 2 THEN UNIFORM(1000, 2000, RANDOM()) WHEN 3 THEN UNIFORM(600, 1200, RANDOM())
                         WHEN 4 THEN UNIFORM(800, 1800, RANDOM()) WHEN 5 THEN UNIFORM(1200, 2500, RANDOM())
                         WHEN 6 THEN UNIFORM(400, 1000, RANDOM()) WHEN 7 THEN UNIFORM(1500, 3000, RANDOM())
                         WHEN 8 THEN UNIFORM(2000, 4000, RANDOM()) ELSE UNIFORM(500, 1000, RANDOM()) END AS LIFESPAN
            FROM (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS I,
                         UNIFORM(0, 9, RANDOM()) AS T,
                         UNIFORM(30, 800, RANDOM()) AS AGE_DAYS,
                         UNIFORM(4::FLOAT, 20::FLOAT, RANDOM()) AS DUTY_HRS,
                         UNIFORM(-0.20::FLOAT, 0.20::FLOAT, RANDOM()) AS NOISE
                  FROM TABLE(GENERATOR(ROWCOUNT => 3000))) h
        ) g
        JOIN _ROBOT_CTX rc ON rc.ROBOT_IDX = MOD(g.I, 600)
    ) v
) w;

-- ============================================================================
-- ROBOT_TELEMETRY (150,000 readings over 12 months, ending at churn for churned)
-- ============================================================================
INSERT INTO ROBOT_TELEMETRY
SELECT
    'TEL-' || LPAD(g.I::VARCHAR, 7, '0') AS TELEMETRY_ID,
    rc.ROBOT_ID,
    DATEADD(SECOND, -1 * UNIFORM(0, 31536000, RANDOM()), rc.CUTOFF_TS) AS TIMESTAMP,
    ROUND(UNIFORM(5::FLOAT, 100::FLOAT, RANDOM()), 1) AS BATTERY_LEVEL,
    ROUND(UNIFORM(25::FLOAT, 80::FLOAT, RANDOM()) + g.STRESS * 6, 1) AS CPU_TEMPERATURE_C,
    ROUND(UNIFORM(30::FLOAT, 100::FLOAT, RANDOM()) + g.STRESS * 12, 1) AS MOTOR_TEMPERATURE_C,
    ROUND(UNIFORM(0.1::FLOAT, 12::FLOAT, RANDOM()) + g.STRESS * 3, 2) AS VIBRATION_MM_S,
    ROUND(UNIFORM(5::FLOAT, 95::FLOAT, RANDOM()), 1) AS JOINT_LOAD_PERCENT,
    ROUND(UNIFORM(0::FLOAT, 3.5::FLOAT, RANDOM()), 2) AS SPEED_M_S,
    ROUND(UNIFORM(-15::FLOAT, 15::FLOAT, RANDOM()), 2) AS ORIENTATION_ROLL,
    ROUND(UNIFORM(-20::FLOAT, 20::FLOAT, RANDOM()), 2) AS ORIENTATION_PITCH,
    ROUND(UNIFORM(-180::FLOAT, 180::FLOAT, RANDOM()), 2) AS ORIENTATION_YAW,
    ROUND(UNIFORM(-50::FLOAT, 50::FLOAT, RANDOM()), 2) AS LOCATION_X,
    ROUND(UNIFORM(-50::FLOAT, 50::FLOAT, RANDOM()), 2) AS LOCATION_Y,
    ROUND(UNIFORM(0::FLOAT, 5::FLOAT, RANDOM()), 2) AS LOCATION_Z,
    GET(ARRAY_CONSTRUCT('Autonomous Navigation','Remote Control','Inspection Mode','Material Handling',
        'Idle Standby','Charging'), MOD(g.I, 6))::VARCHAR AS OPERATIONAL_MODE,
    CASE WHEN UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.04 + g.STRESS * 0.06
         THEN 'ERR-' || LPAD(UNIFORM(100, 999, RANDOM())::VARCHAR, 3, '0') END AS ERROR_CODE
FROM (SELECT g0.I, IFF(rc0.PROFILE IN ('AT_RISK','CHURNED'), 1, 0) * UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) AS STRESS,
             rc0.ROBOT_IDX
      FROM (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS I FROM TABLE(GENERATOR(ROWCOUNT => 150000))) g0
      JOIN _ROBOT_CTX rc0 ON rc0.ROBOT_IDX = MOD(g0.I, 600)) g
JOIN _ROBOT_CTX rc ON rc.ROBOT_IDX = g.ROBOT_IDX;

-- ============================================================================
-- MAINTENANCE_RECORDS (6,000 over 12 months). COMPONENT_ID belongs to the robot.
-- ============================================================================
INSERT INTO MAINTENANCE_RECORDS
SELECT
    'MNT-' || LPAD(g.I::VARCHAR, 5, '0') AS MAINTENANCE_ID,
    rc.ROBOT_ID,
    CASE WHEN UNIFORM(1, 10, RANDOM()) <= 7
         THEN 'COMP-' || LPAD((rc.ROBOT_IDX + 600 * UNIFORM(0, 4, RANDOM()))::VARCHAR, 5, '0') END AS COMPONENT_ID,
    GET(ARRAY_CONSTRUCT('Preventive','Corrective','Predictive','Firmware Update','Calibration'), g.T)::VARCHAR AS MAINTENANCE_TYPE,
    GET(ARRAY_CONSTRUCT(
        'Routine motor inspection and lubrication completed',
        'Battery health check and cell balancing performed',
        'Replaced worn joint actuator bearings',
        'Firmware upgraded to latest stable release',
        'LiDAR sensor recalibrated after drift detected',
        'Emergency motor replacement due to overheating',
        'Camera lens cleaned and alignment verified',
        'Hydraulic system pressure test and fluid replacement',
        'Communication module antenna replacement',
        'Full system diagnostic and safety certification'), MOD(g.I, 10))::VARCHAR AS DESCRIPTION,
    GET(ARRAY_CONSTRUCT('Alex Martinez','Jordan Lee','Sam Nguyen','Robin Patel','Casey Williams',
        'Morgan Brown','Taylor Kim','Jamie O''Connor'), MOD(g.I, 8))::VARCHAR AS PERFORMED_BY,
    DATEADD(MINUTE, -1 * ROUND(525600 * POW(UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()), rc.RECENCY_EXP))::INT, rc.CUTOFF_TS) AS PERFORMED_AT,
    UNIFORM(15, 480, RANDOM()) AS DURATION_MINUTES,
    ROUND(CASE g.T WHEN 1 THEN UNIFORM(800::FLOAT, 12000::FLOAT, RANDOM())
                   WHEN 0 THEN UNIFORM(150::FLOAT, 2500::FLOAT, RANDOM())
                   ELSE UNIFORM(50::FLOAT, 4000::FLOAT, RANDOM()) END, 2) AS COST_USD,
    CASE WHEN UNIFORM(1, 10, RANDOM()) <= 4
         THEN GET(ARRAY_CONSTRUCT('Motor bearings, seals','Battery cells','Actuator assembly','Sensor module',
              'Hydraulic hoses','Controller board'), MOD(g.I, 6))::VARCHAR END AS PARTS_REPLACED,
    IFF(MOD(g.I, 4) = 3, 'Monitoring', 'Resolved') AS OUTCOME,
    DATEADD(DAY, UNIFORM(14, 180, RANDOM()), CURRENT_DATE()) AS NEXT_SCHEDULED
FROM (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS I, UNIFORM(0, 4, RANDOM()) AS T
      FROM TABLE(GENERATOR(ROWCOUNT => 6000))) g
JOIN _ROBOT_CTX rc ON rc.ROBOT_IDX = MOD(g.I, 600);

-- ============================================================================
-- INCIDENTS (~1,400). Rate and recency driven by customer profile.
-- Fix: RESOLVED_AT is always after REPORTED_AT, and RESOLUTION is populated
--      exactly when RESOLVED_AT is.
-- ============================================================================
INSERT INTO INCIDENTS
SELECT
    'INC-' || LPAD((ROW_NUMBER() OVER (ORDER BY x.REPORTED_AT) - 1)::VARCHAR, 5, '0') AS INCIDENT_ID,
    x.ROBOT_ID,
    x.DEPLOYMENT_ID,
    GET(ARRAY_CONSTRUCT('Hardware Failure','Software Error','Communication Loss','Sensor Malfunction',
        'Navigation Error','Battery Critical','Emergency Stop','Environmental Hazard'), x.T)::VARCHAR AS INCIDENT_TYPE,
    CASE WHEN x.SEV_U < IFF(x.PROFILE IN ('AT_RISK','CHURNED'), 0.25, 0.10) THEN 'Critical'
         WHEN x.SEV_U < IFF(x.PROFILE IN ('AT_RISK','CHURNED'), 0.55, 0.35) THEN 'High'
         WHEN x.SEV_U < 0.75 THEN 'Medium' ELSE 'Low' END AS SEVERITY,
    GET(ARRAY_CONSTRUCT(
        'Motor overtemperature alarm triggered during heavy load operation. Robot entered safe mode automatically.',
        'Navigation stack crash caused robot to halt. Restart required. Logs collected for analysis.',
        'Lost 5G connectivity for 15 minutes on site. Robot operated in offline mode.',
        'LiDAR returned inconsistent point cloud data. Obstacle detection compromised temporarily.',
        'Path planning failure at intersection. Robot unable to navigate around dynamic obstacle.',
        'Battery dropped below 8% with no charging station in range. Emergency retrieval required.',
        'E-stop triggered by human operator during close-proximity operation. Safety protocol activated.',
        'Water ingress detected in outdoor deployment during heavy rain. Sealed compartments held.'), x.T)::VARCHAR AS DESCRIPTION,
    x.REPORTED_AT,
    IFF(x.IS_RESOLVED, DATEADD(MINUTE, x.RES_MIN, x.REPORTED_AT), NULL) AS RESOLVED_AT,
    IFF(x.IS_RESOLVED, GET(ARRAY_CONSTRUCT(
        'Component replaced and system recalibrated',
        'Software patched and functionality restored',
        'Network equipment reset and signal boosted',
        'Sensor recalibrated and validated against reference',
        'Map updated and navigation retested successfully',
        'Battery replaced and charging protocol reviewed',
        'Safety zone reconfigured and operator retrained',
        'Enclosure seals replaced and IP rating verified'), x.T)::VARCHAR, NULL) AS RESOLUTION,
    GET(ARRAY_CONSTRUCT('Component wear','Software bug','Network infrastructure','Environmental conditions',
        'Calibration drift','Power supply fluctuation','Operator error'), MOD(x.T + x.K, 7))::VARCHAR AS ROOT_CAUSE,
    ROUND(x.RES_MIN * IFF(x.PROFILE IN ('AT_RISK','CHURNED'), 0.9, 0.6))::INT AS DOWNTIME_MINUTES
FROM (
    SELECT y.*,
        (y.RES_U < 0.85 AND DATEADD(MINUTE, y.RES_MIN, y.REPORTED_AT) < y.CUTOFF_TS) AS IS_RESOLVED
    FROM (
        SELECT rc.ROBOT_ID, rc.DEPLOYMENT_ID, rc.PROFILE, rc.CUTOFF_TS,
            SEQ4() AS K,
            UNIFORM(0, 7, RANDOM()) AS T,
            UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) AS SEV_U,
            UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) AS RES_U,
            UNIFORM(15, 2880, RANDOM()) AS RES_MIN,
            UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) AS KEEP_U,
            DATEADD(MINUTE, -1 * ROUND(525600 * POW(UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()), rc.RECENCY_EXP))::INT, rc.CUTOFF_TS) AS REPORTED_AT
        FROM _ROBOT_CTX rc, TABLE(GENERATOR(ROWCOUNT => 5))
    ) y
    WHERE y.KEEP_U < CASE y.PROFILE WHEN 'AT_RISK' THEN 0.85 WHEN 'CHURNED' THEN 0.75
                                    WHEN 'EXPANDING' THEN 0.35 ELSE 0.40 END
) x;

-- ============================================================================
-- KNOWLEDGE_BASE (25 distinct articles; fleet + customer success playbooks)
-- ============================================================================
INSERT INTO KNOWLEDGE_BASE (ARTICLE_ID, TITLE, CATEGORY, SUBCATEGORY, CONTENT, ROBOT_MODEL, TAGS, AUTHOR, CREATED_AT, UPDATED_AT)
SELECT 'KB-' || LPAD(column1::VARCHAR, 4, '0'), column2, column3, column4, column5, column6, column7, column8,
       DATEADD(DAY, -1 * UNIFORM(30, 365, RANDOM()), CURRENT_TIMESTAMP()),
       DATEADD(DAY, -1 * UNIFORM(0, 29, RANDOM()), CURRENT_TIMESTAMP())
FROM VALUES
(0,'Atlas Humanoid Robot Overview and Specifications','Product Specifications','Product Overview',
 'The all-electric Atlas stands 1.5 m tall, weighs about 89 kg and has 28 degrees of freedom. Custom high-torque electric actuators replace the earlier hydraulic system, improving power density and reducing maintenance. Atlas performs bipedal walking on uneven terrain, dynamic balance recovery, whole-body manipulation and autonomous navigation. Typical commercial applications are automotive part sequencing, kitting, and moving totes between fixtures in manufacturing cells. Runtime is roughly 2 hours per battery swap.','Atlas','specifications,overview,humanoid','Lisa Park, Product Documentation'),
(1,'Spot Quadruped Technical Specifications','Product Specifications','Product Overview',
 'Spot weighs 32.7 kg, carries up to 14 kg of payload and walks at up to 1.6 m/s. It climbs stairs up to 30 degrees, operates from -20 C to 45 C and is rated IP54. Five stereo camera pairs provide 360-degree obstacle avoidance. Runtime is about 90 minutes and the Spot Dock enables fully autonomous charging. Payload options include Spot CAM+IR thermal imaging, Spot Arm, LiDAR mapping and acoustic leak detection.','Spot','specifications,overview,quadruped','Lisa Park, Product Documentation'),
(2,'Stretch Warehouse Robot Capabilities','Product Specifications','Product Overview',
 'Stretch is a mobile manipulation robot for truck unloading and pallet building. It combines an omnidirectional base, a 7-DOF arm, a smart vacuum gripper and the Perception Mast. Stretch moves up to 600 cases per hour, handles boxes up to 23 kg and operates for a full 8-hour shift on one charge. It integrates with warehouse management systems through the Stretch Fleet API and requires no fixed infrastructure.','Stretch','specifications,overview,warehouse','Lisa Park, Product Documentation'),
(3,'Atlas Joint Calibration Procedure','Technical Procedures','Configuration',
 'Perform joint calibration after any actuator replacement or when position error exceeds 0.5 degrees. 1) Place Atlas in the calibration fixture and enable maintenance mode from the tablet. 2) Run the zeroing routine joint by joint, starting with the ankles and moving up the kinematic chain. 3) Verify encoder offsets against the reference values in the service portal. 4) Run the balance self-test and confirm all joints report within tolerance. Record results in the maintenance log.','Atlas','calibration,joints,actuator,maintenance','Dr. Sarah Kim, Robotics Engineering'),
(4,'Spot Autonomous Navigation and Autowalk Setup','Technical Procedures','Configuration',
 'Autowalk lets Spot repeat inspection routes autonomously. Record a mission by driving Spot along the route with the tablet and dropping fiducials at junctions and docks. Add actions such as thermal captures or gauge reads at waypoints. Use Graph Nav to localize; place fiducials no more than 10 m apart in feature-poor areas. Validate the mission three times before scheduling it. If localization fails, check lighting, fiducial visibility and map changes.','Spot','navigation,autowalk,missions,setup','Michael Chen, Field Service'),
(5,'Stretch Vacuum Gripper Maintenance Protocol','Maintenance','Repair & Service',
 'Inspect the vacuum gripper suction cups every 250 operating hours. Replace any cup with cracks, flattening or lost seal. Clean the filter cartridge weekly in dusty environments and replace it every 1,000 hours. A drop in vacuum pressure below 60 kPa during pick indicates a leak; check cup seating, hoses and the vacuum pump. Run the grip self-test after any service before returning Stretch to production.','Stretch','gripper,vacuum,maintenance','Michael Chen, Field Service'),
(6,'Battery Management Best Practices','Maintenance','Repair & Service',
 'Keep batteries between 20% and 90% state of charge for longest life. Avoid storing batteries fully charged for more than 7 days. Charge at 10-35 C ambient. Batteries that lose more than 20% capacity from new should be scheduled for replacement. Cell imbalance above 50 mV triggers a balancing cycle; repeated imbalance indicates a failing cell. Never operate a battery with swelling or physical damage.','All Models','battery,charging,maintenance','Emma Watson, Safety Engineering'),
(7,'Motor Overheating Troubleshooting Guide','Troubleshooting','Repair & Service',
 'Motor temperature above 85 C triggers a warning and above 95 C triggers thermal shutdown. Common causes: blocked cooling vents, sustained joint load above 80%, worn bearings, and high ambient temperature. Steps: 1) Check telemetry for joint load and vibration trends. 2) Inspect and clean vents and fans. 3) Measure vibration; values above 10 mm/s indicate bearing wear. 4) Apply firmware thermal management updates. 5) Replace the motor if temperatures remain high under normal load.','All Models','motor,temperature,overheating,troubleshooting','Michael Chen, Field Service'),
(8,'LiDAR Calibration and Accuracy Verification','Technical Procedures','Configuration',
 'Calibrate LiDAR when point cloud drift exceeds 2 cm or after a collision. Mount the calibration target 3 m from the robot, run the extrinsic calibration tool and verify the residual error is below 1 cm. Clean the lens with a lint-free cloth and isopropyl alcohol. Inconsistent point clouds in rain, dust or steam are expected; enable the weather filter for outdoor deployments.','All Models','lidar,calibration,sensors','Dr. Sarah Kim, Robotics Engineering'),
(9,'Communication Module and Network Recovery','Troubleshooting','Repair & Service',
 'When a robot loses connectivity it continues its current mission and returns to the last known safe point after 5 minutes. To recover: verify site Wi-Fi or private 5G coverage at the loss location, check antenna connectors, and review the radio logs for interference. Install mesh radios in areas with heavy metal structures. Persistent drops in one zone usually indicate an access point configuration issue rather than a robot fault.','All Models','network,5g,wifi,connectivity','Michael Chen, Field Service'),
(10,'Emergency Stop Protocol and Safety Guidelines','Safety & Compliance','Safety',
 'Every robot supports hardware E-stop from the tablet and wireless E-stop units. Operators must keep an E-stop within reach whenever people are inside the safety zone. After an E-stop, inspect the area, confirm the cause, and restart from the tablet. Frequent E-stops in one location indicate a safety zone design issue; review zone boundaries and operator training. Log all E-stops as incidents.','All Models','safety,estop,compliance','Emma Watson, Safety Engineering'),
(11,'Firmware Update Procedures','Maintenance','Software',
 'Schedule updates during planned downtime. Confirm battery above 50% and stable power before starting. Updates are staged over the air and applied on reboot; do not power off during installation. If an update is interrupted the robot boots into recovery mode and retries automatically. Critical security releases should be applied within 14 days. Check release notes for affected components and run the post-update self-test.','All Models','firmware,update,ota,software','Robert Playter, CTO Office'),
(12,'Predictive Maintenance Sensor Thresholds','Maintenance','Predictive',
 'Recommended alert thresholds: motor temperature above 85 C, vibration above 10 mm/s, battery below 15%, joint load sustained above 85% for 10 minutes, and CPU temperature above 80 C. Components past 90% of expected lifespan should be scheduled for replacement within 30 days; past 75% within 90 days. Combine these signals in the predictive maintenance model to prioritise work orders.','All Models','predictive,thresholds,telemetry,rul','Dr. Sarah Kim, Robotics Engineering'),
(13,'Spot Thermal Inspection with CAM+IR','Technical Procedures','Inspection',
 'Spot CAM+IR captures radiometric thermal images for electrical and mechanical inspection. Set emissivity per asset type (0.95 for painted surfaces, 0.3 for bare metal). Capture from the same pose each mission for trend comparison. Configure alerts for absolute temperature and for rises above the trailing 30-day baseline. Typical uses: switchgear hot spots, pump bearings, steam traps and pipe insulation failures.','Spot','thermal,inspection,camera','Michael Chen, Field Service'),
(14,'Stretch Truck Unloading Optimization','Operations','Throughput',
 'To maximise Stretch throughput: stage trailers with the door fully open and dock plates level, keep the conveyor speed matched to pick rate, and enable mixed-SKU mode for floor-loaded trailers. Typical throughput is 500-600 cases per hour. Low throughput is usually caused by conveyor backups, poor lighting at the trailer nose, or damaged cases requiring manual handling.','Stretch','throughput,unloading,operations','Lisa Park, Product Documentation'),
(15,'Outdoor Deployment Weather Protection Guide','Safety & Compliance','Environment',
 'Spot is rated IP54 and can operate in light rain and snow. Avoid standing water deeper than 15 cm and temperatures outside -20 C to 45 C. After wet operation, dry the robot and inspect seals before charging. Atlas and Stretch are indoor products; do not deploy them outdoors without an approved enclosure. Water ingress incidents should trigger a seal inspection on all robots at that site.','All Models','weather,outdoor,ip54,environment','Emma Watson, Safety Engineering'),
(16,'Incident Response and Escalation Procedures','Troubleshooting','Support',
 'Severity definitions: Critical - safety risk or full site stoppage, 1-hour response; High - multiple robots impaired, 4-hour response; Medium - single robot impaired, next business day; Low - question or minor defect. Critical incidents page the on-call field engineer and notify the customer success manager. Provide robot ID, logs and telemetry window when opening a case.','All Models','incident,escalation,support,sla','Michael Chen, Field Service'),
(17,'Robot Fleet Management Best Practices','Operations','Fleet',
 'Track fleet utilization, mission success rate, and mean time between failures per site. Rotate robots between high- and low-load missions to balance component wear. Keep at least 10% spare capacity for maintenance windows. Review incident trends monthly with site leads. Standardize firmware versions across a site to simplify support.','All Models','fleet,operations,utilization','Robert Playter, CTO Office'),
(18,'Component Lifetime Estimation Methods','Maintenance','Predictive',
 'Remaining useful life (RUL) is estimated from expected lifespan, days in service, runtime hours, and condition signals such as vibration and temperature. The fleet RUL model uses gradient boosting over these features. Treat RUL estimates under 30 days as urgent and under 90 days as plan-ahead. Recalibrate expected lifespans each quarter using actual failure history.','All Models','rul,lifetime,predictive,ml','Dr. Sarah Kim, Robotics Engineering'),
(19,'Warranty Terms and Service Level Agreements','Safety & Compliance','Commercial',
 'Standard warranty covers parts and labour for 12 months. Platinum support adds 24x7 coverage, 1-hour critical response and on-site spares. Gold provides 4-hour critical response; Silver next-business-day; Bronze email support. SLA attainment is measured monthly. Service credits apply when critical response SLA attainment falls below 95% in a month.','All Models','warranty,sla,support,tiers','Customer Success Office'),
(20,'Customer Success Playbook: Onboarding','Customer Success','Playbook',
 'The first 90 days determine long-term adoption. Milestones: kickoff and success plan within 2 weeks, first robot in production by day 30, operator certification by day 45, first autonomous mission by day 60, and a value review by day 90. Assign a named CSM and schedule weekly check-ins. Track time-to-first-mission and autonomy percentage as leading indicators.','All Models','customer success,onboarding,playbook','Customer Success Office'),
(21,'Customer Success Playbook: At-Risk Account Recovery','Customer Success','Playbook',
 'Warning signs: declining robot utilization, NPS detractor responses, rising critical incidents, SLA misses, late invoice payments and a champion leaving. Recovery steps: 1) Executive sponsor call within 5 days. 2) Joint root-cause review of incidents with field engineering. 3) Remediation plan with dated commitments. 4) Weekly status until health score recovers above 70. 5) Consider service credits or a no-cost training refresh. Escalate to the VP Customer Success if renewal is within 120 days.','All Models','customer success,churn,risk,recovery,playbook','Customer Success Office'),
(22,'Customer Success Playbook: Renewal Management','Customer Success','Playbook',
 'Start renewal planning 180 days before contract end. At 180 days confirm health score and stakeholders; at 120 days deliver a value realisation review with ROI metrics; at 90 days send the renewal proposal; at 60 days resolve commercial questions; close by 30 days. Accounts with health score under 50 or churn risk above 60% require a recovery plan before the proposal goes out.','All Models','customer success,renewal,contracts,playbook','Customer Success Office'),
(23,'Customer Success Playbook: Expansion Opportunities','Customer Success','Playbook',
 'Strong expansion signals: utilization above 85%, autonomy above 90%, promoter NPS, new sites under construction, and requests for additional payloads. Typical expansion paths are adding robots at an existing site, replicating a proven use case at a new site, upgrading to Spot Arm or thermal payloads, and moving from lease to Robots-as-a-Service. Engage the account executive once expansion propensity exceeds 60%.','All Models','customer success,expansion,upsell,playbook','Customer Success Office'),
(24,'Customer Health Score Methodology','Customer Success','Analytics',
 'The customer health score (0-100) combines product adoption (utilization, autonomy, active robots trend), customer sentiment (NPS, CSAT, interaction sentiment), support experience (ticket volume per robot, SLA attainment), operational reliability (critical incidents, downtime) and commercial health (on-time payment rate). A machine learning model learns weights from historical outcomes. Bands: 75-100 Healthy, 50-74 Monitor, below 50 At Risk.','All Models','health score,customer success,ml,methodology','Customer Success Office');

-- ============================================================================
-- FIRMWARE_RELEASES (30)
-- ============================================================================
INSERT INTO FIRMWARE_RELEASES
SELECT
    'FW-' || LPAD(I::VARCHAR, 4, '0') AS RELEASE_ID,
    CASE MOD(I, 3) WHEN 0 THEN '3.' WHEN 1 THEN '4.' ELSE '2.' END || (FLOOR(I / 3) + 1)::VARCHAR || '.' || MOD(I * 7, 20)::VARCHAR AS VERSION,
    CASE MOD(I, 3) WHEN 0 THEN 'Atlas' WHEN 1 THEN 'Spot' ELSE 'Stretch' END AS ROBOT_MODEL,
    DATEADD(DAY, -1 * (730 - I * 24), CURRENT_DATE()) AS RELEASE_DATE,
    GET(ARRAY_CONSTRUCT('Improved motor temperature management and thermal throttling algorithms',
        'Enhanced autonomous navigation with better obstacle avoidance',
        'Battery management optimization for extended runtime',
        'Critical security patches and communication encryption updates',
        'New manipulation algorithms for improved gripper precision',
        'Sensor fusion improvements for better environmental awareness'), MOD(I, 6))::VARCHAR AS RELEASE_NOTES,
    MOD(I, 5) = 0 AS IS_CRITICAL,
    GET(ARRAY_CONSTRUCT('Motor Controller, Safety System','Navigation Stack, LiDAR Driver',
        'Battery Management, Power Distribution','Communication Module, Encryption Engine'), MOD(I, 4))::VARCHAR AS AFFECTED_COMPONENTS
FROM (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS I FROM TABLE(GENERATOR(ROWCOUNT => 30)));

-- ============================================================================
-- CUSTOMER 360: fleet size per customer (drives ARR and usage)
-- ============================================================================
CREATE OR REPLACE TEMPORARY TABLE _CUST_FLEET AS
SELECT p.CUSTOMER_ID, p.N, p.PROFILE, p.CHURN_DATE, p.CUTOFF_TS, p.RECENCY_EXP,
       COUNT(rc.ROBOT_ID) AS ROBOT_CNT,
       COUNT_IF(rc.ROBOT_MODEL = 'Atlas') AS ATLAS_CNT,
       COUNT_IF(rc.ROBOT_MODEL = 'Spot') AS SPOT_CNT,
       COUNT_IF(rc.ROBOT_MODEL = 'Stretch') AS STRETCH_CNT,
       ARRAY_AGG(rc.ROBOT_ID) AS ROBOT_IDS
FROM _CUST_PROFILE p
LEFT JOIN _ROBOT_CTX rc ON rc.CUSTOMER_ID = p.CUSTOMER_ID
GROUP BY ALL;

-- ============================================================================
-- CONTACTS (400 = 4 per customer)
-- ============================================================================
INSERT INTO CONTACTS
SELECT
    'CON-' || LPAD((x.N * 4 + x.K)::VARCHAR, 5, '0') AS CONTACT_ID,
    x.CUSTOMER_ID,
    x.FIRST_NAME || ' ' || x.LAST_NAME AS FULL_NAME,
    GET(ARRAY_CONSTRUCT('VP of Operations','Director of Robotics & Automation','Lead Robotics Engineer','Procurement Manager'), x.K)::VARCHAR AS TITLE,
    GET(ARRAY_CONSTRUCT('Economic Buyer','Champion','Technical User','Procurement'), x.K)::VARCHAR AS CONTACT_ROLE,
    LOWER(x.FIRST_NAME || '.' || x.LAST_NAME || '@' || REGEXP_REPLACE(x.CUSTOMER_NAME, '[^A-Za-z0-9]', '') || '.com') AS EMAIL,
    '+1-555-' || LPAD(UNIFORM(100, 999, RANDOM())::VARCHAR, 3, '0') || '-' || LPAD(UNIFORM(1000, 9999, RANDOM())::VARCHAR, 4, '0') AS PHONE,
    x.K = 1 AS IS_PRIMARY
FROM (
    SELECT p.N, p.CUSTOMER_ID, s.CUSTOMER_NAME, g.K,
        GET(ARRAY_CONSTRUCT('Michael','Jennifer','David','Laura','Kenji','Anita','Carlos','Sophie','Ahmed','Olivia',
            'Raj','Emily','Lars','Mei','Diego','Fatima','Thomas','Yuki','Daniel','Ingrid'), MOD(p.N * 7 + g.K * 3, 20))::VARCHAR AS FIRST_NAME,
        GET(ARRAY_CONSTRUCT('Anderson','Nakamura','Schmidt','Garcia','Okonkwo','Kowalski','Silva','Dubois','Singh','Johansson',
            'Murphy','Tanaka','Rossi','Kim','Hughes','Martin','Novak','Costa','Reyes','Fischer'), MOD(p.N * 3 + g.K * 11, 20))::VARCHAR AS LAST_NAME
    FROM _CUST_PROFILE p
    JOIN _CUST_SEED s ON s.N = p.N
    CROSS JOIN (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS K FROM TABLE(GENERATOR(ROWCOUNT => 4))) g
) x;

-- ============================================================================
-- CONTRACTS: 1-3 consecutive annual terms per customer (K = 0 is the latest),
-- plus a co-terminous Expansion contract for EXPANDING customers.
-- At-risk customers have renewals coming due soon; churned ended at churn date.
-- ============================================================================
CREATE OR REPLACE TEMPORARY TABLE _CUST_TERM AS
SELECT f.*,
    CASE f.PROFILE WHEN 'CHURNED' THEN f.CHURN_DATE
                   WHEN 'AT_RISK' THEN DATEADD(DAY, UNIFORM(20, 150, RANDOM()), CURRENT_DATE())
                   ELSE DATEADD(DAY, UNIFORM(15, 360, RANDOM()), CURRENT_DATE()) END AS LATEST_END,
    1 + MOD(FLOOR(f.N / 3), 3) AS N_TERMS,
    (f.SPOT_CNT * 60000 + f.STRETCH_CNT * 110000 + f.ATLAS_CNT * 180000) AS FULL_ARR,
    GET(ARRAY_CONSTRUCT('RaaS Subscription','Lease','Purchase + Support'), MOD(f.N, 3))::VARCHAR AS CONTRACT_TYPE,
    CASE WHEN f.STRETCH_CNT >= GREATEST(f.SPOT_CNT, f.ATLAS_CNT) THEN 'Stretch'
         WHEN f.ATLAS_CNT >= f.SPOT_CNT THEN 'Atlas' ELSE 'Spot' END AS PRODUCT_LINE
FROM _CUST_FLEET f;

INSERT INTO CONTRACTS
SELECT
    'CTR-' || LPAD((ROW_NUMBER() OVER (ORDER BY START_DATE, CUSTOMER_ID) - 1)::VARCHAR, 5, '0') AS CONTRACT_ID,
    CUSTOMER_ID, CONTRACT_TYPE, PRODUCT_LINE, START_DATE, END_DATE, ARR_USD,
    ROUND(ARR_USD * DATEDIFF(DAY, START_DATE, END_DATE) / 365, 2) AS TCV_USD,
    ROBOT_QUANTITY, AUTO_RENEW, STATUS
FROM (
    -- Base annual terms
    SELECT t.CUSTOMER_ID, t.CONTRACT_TYPE, t.PRODUCT_LINE,
        DATEADD(DAY, -365 * (g.K + 1), t.LATEST_END) AS START_DATE,
        DATEADD(DAY, -365 * g.K - IFF(g.K = 0, 0, 1), t.LATEST_END) AS END_DATE,
        ROUND(t.FULL_ARR * IFF(t.PROFILE = 'EXPANDING', 0.75, 1.0) * POW(0.9, g.K), 2) AS ARR_USD,
        GREATEST(1, ROUND(t.ROBOT_CNT * IFF(t.PROFILE = 'EXPANDING', 0.75, 1.0) * POW(0.9, g.K)))::INT AS ROBOT_QUANTITY,
        MOD(t.N, 4) <> 0 AS AUTO_RENEW,
        CASE WHEN g.K > 0 THEN 'Renewed' WHEN t.PROFILE = 'CHURNED' THEN 'Churned' ELSE 'Active' END AS STATUS
    FROM _CUST_TERM t
    CROSS JOIN (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS K FROM TABLE(GENERATOR(ROWCOUNT => 3))) g
    WHERE g.K < t.N_TERMS
    UNION ALL
    -- Expansion contracts
    SELECT t.CUSTOMER_ID, 'Expansion', t.PRODUCT_LINE,
        DATEADD(DAY, -1 * UNIFORM(30, 270, RANDOM()), CURRENT_DATE()),
        t.LATEST_END,
        ROUND(t.FULL_ARR * 0.25, 2),
        GREATEST(1, ROUND(t.ROBOT_CNT * 0.25))::INT,
        TRUE, 'Active'
    FROM _CUST_TERM t
    WHERE t.PROFILE = 'EXPANDING'
);

-- Roll contract dates up to CUSTOMERS and set lifecycle stage
UPDATE CUSTOMERS c SET
    CONTRACT_START_DATE = x.CUR_START,
    CONTRACT_END_DATE   = x.CUR_END,
    CUSTOMER_SINCE      = x.FIRST_START,
    LIFECYCLE_STAGE = CASE
        WHEN p.PROFILE = 'CHURNED' THEN 'Churned'
        WHEN DATEDIFF(DAY, x.FIRST_START, CURRENT_DATE()) < 180 THEN 'Onboarding'
        WHEN DATEDIFF(DAY, CURRENT_DATE(), x.CUR_END) <= 120 THEN 'Renewal Due'
        WHEN DATEDIFF(DAY, x.FIRST_START, CURRENT_DATE()) < 540 THEN 'Adopting'
        ELSE 'Mature' END
FROM (SELECT CUSTOMER_ID, MIN(START_DATE) AS FIRST_START,
             MAX(IFF(CONTRACT_TYPE <> 'Expansion', START_DATE, NULL)) AS CUR_START,
             MAX(END_DATE) AS CUR_END
      FROM CONTRACTS GROUP BY CUSTOMER_ID) x,
     _CUST_PROFILE p
WHERE x.CUSTOMER_ID = c.CUSTOMER_ID AND p.CUSTOMER_ID = c.CUSTOMER_ID;

-- Keep deployment and manufacture dates on or after the first contract
UPDATE DEPLOYMENTS d SET DEPLOYMENT_DATE = DATEADD(DAY, UNIFORM(0, 60, RANDOM()), c.CUSTOMER_SINCE)
FROM CUSTOMERS c WHERE c.CUSTOMER_ID = d.CUSTOMER_ID AND d.DEPLOYMENT_DATE < c.CUSTOMER_SINCE;

-- ============================================================================
-- INVOICES: monthly billing per contract up to today. Payment behaviour by profile.
-- ============================================================================
INSERT INTO INVOICES
SELECT
    'INV-' || LPAD((ROW_NUMBER() OVER (ORDER BY y.INVOICE_DATE, y.CONTRACT_ID) - 1)::VARCHAR, 6, '0') AS INVOICE_ID,
    y.CONTRACT_ID, y.CUSTOMER_ID, y.INVOICE_DATE, y.DUE_DATE, y.AMOUNT_USD,
    IFF(y.PAY_DATE <= CURRENT_DATE(), y.PAY_DATE, NULL) AS PAID_DATE,
    CASE WHEN y.PAY_DATE <= CURRENT_DATE() THEN IFF(y.DAYS_LATE_RAW > 0, 'Paid Late', 'Paid')
         WHEN y.DUE_DATE < CURRENT_DATE() THEN 'Overdue'
         ELSE 'Open' END AS PAYMENT_STATUS,
    CASE WHEN y.PAY_DATE <= CURRENT_DATE() THEN GREATEST(y.DAYS_LATE_RAW, 0)
         WHEN y.DUE_DATE < CURRENT_DATE() THEN DATEDIFF(DAY, y.DUE_DATE, CURRENT_DATE())
         ELSE 0 END AS DAYS_LATE
FROM (
    SELECT x.*, DATEADD(DAY, x.DAYS_LATE_RAW, x.DUE_DATE) AS PAY_DATE
    FROM (
        SELECT ct.CONTRACT_ID, ct.CUSTOMER_ID,
            DATEADD(MONTH, g.M, ct.START_DATE) AS INVOICE_DATE,
            DATEADD(DAY, 30, DATEADD(MONTH, g.M, ct.START_DATE)) AS DUE_DATE,
            ROUND(ct.ARR_USD / 12, 2) AS AMOUNT_USD,
            IFF(UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) <
                CASE p.PROFILE WHEN 'CHURNED' THEN 0.45 WHEN 'AT_RISK' THEN 0.35 WHEN 'EXPANDING' THEN 0.03 ELSE 0.06 END,
                UNIFORM(5, 75, RANDOM()), UNIFORM(-10, 0, RANDOM())) AS DAYS_LATE_RAW
        FROM CONTRACTS ct
        JOIN _CUST_PROFILE p ON p.CUSTOMER_ID = ct.CUSTOMER_ID
        CROSS JOIN (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS M FROM TABLE(GENERATOR(ROWCOUNT => 12))) g
        WHERE DATEADD(MONTH, g.M, ct.START_DATE) < ct.END_DATE
          AND DATEADD(MONTH, g.M, ct.START_DATE) <= CURRENT_DATE()
    ) x
) y;

-- ============================================================================
-- SUPPORT_TICKETS (~2,900). Volume, priority, speed, SLA and CSAT by profile.
-- ============================================================================
INSERT INTO SUPPORT_TICKETS
SELECT
    'TKT-' || LPAD((ROW_NUMBER() OVER (ORDER BY z.OPENED_AT) - 1)::VARCHAR, 6, '0') AS TICKET_ID,
    z.CUSTOMER_ID,
    'CON-' || LPAD((z.N * 4 + MOD(z.K, 4))::VARCHAR, 5, '0') AS CONTACT_ID,
    z.ROBOT_ID,
    z.CATEGORY, z.PRIORITY, z.CHANNEL, z.SUBJECT, z.DESCRIPTION,
    IFF(z.IS_CLOSED, 'Closed', 'Open') AS STATUS,
    z.OPENED_AT,
    IFF(z.IS_CLOSED, DATEADD(MINUTE, ROUND(z.RES_HOURS * 60)::INT, z.OPENED_AT), NULL) AS CLOSED_AT,
    IFF(z.IS_CLOSED, ROUND(z.RES_HOURS, 1), NULL) AS RESOLUTION_HOURS,
    IFF(z.IS_CLOSED, z.RES_HOURS <= z.SLA_HOURS, NULL) AS SLA_MET,
    IFF(z.IS_CLOSED,
        CASE WHEN z.PROFILE IN ('AT_RISK','CHURNED') THEN IFF(z.CSAT_U < 0.75, UNIFORM(1, 3, RANDOM()), 4)
             ELSE IFF(z.CSAT_U < 0.85, UNIFORM(4, 5, RANDOM()), 3) END, NULL) AS CSAT_SCORE,
    GET(ARRAY_CONSTRUCT('Priya Raman','Kevin Walsh','Aisha Bello','Marco Ricci','Sven Larsen','Julia Moreau'), MOD(z.K, 6))::VARCHAR AS ASSIGNED_TO
FROM (
    SELECT y.*,
        CASE y.PRIORITY WHEN 'Critical' THEN 8 WHEN 'High' THEN 24 WHEN 'Medium' THEN 72 ELSE 120 END AS SLA_HOURS,
        DATEADD(MINUTE, ROUND(y.RES_HOURS * 60)::INT, y.OPENED_AT) < LEAST(y.CUTOFF_TS, CURRENT_TIMESTAMP()::TIMESTAMP_NTZ) AS IS_CLOSED
    FROM (
        SELECT x.*,
            CASE x.PRIORITY WHEN 'Critical' THEN UNIFORM(2::FLOAT, 14::FLOAT, RANDOM())
                            WHEN 'High' THEN UNIFORM(4::FLOAT, 36::FLOAT, RANDOM())
                            WHEN 'Medium' THEN UNIFORM(8::FLOAT, 96::FLOAT, RANDOM())
                            ELSE UNIFORM(12::FLOAT, 150::FLOAT, RANDOM()) END
                * IFF(x.PROFILE IN ('AT_RISK','CHURNED'), 2.0, 1.0) AS RES_HOURS,
            GET(ARRAY_CONSTRUCT('Hardware','Software','Navigation','Battery','Connectivity','Integration','Billing','Training'), x.C)::VARCHAR AS CATEGORY,
            GET(ARRAY_CONSTRUCT('Robot hardware fault - joint actuator error','Software crash after firmware update',
                'Robot unable to localize on mission route','Battery not holding charge','Intermittent connectivity loss on site',
                'WMS integration API errors','Invoice discrepancy on monthly billing','Request for operator training'), x.C)::VARCHAR AS SUBJECT,
            GET(ARRAY_CONSTRUCT(
                'Robot reported a joint actuator fault and entered safe mode during operation. Site team needs a field engineer to inspect and replace the part.',
                'After the latest firmware update the robot application crashes intermittently and missions abort. Logs attached from the last three failures.',
                'Robot repeatedly fails to localize at the same waypoint and stops the mission. Map and fiducials were checked by the site team.',
                'Battery runtime has dropped significantly and the robot returns to dock well before the mission completes.',
                'Robots lose connection in one area of the facility, interrupting missions and telemetry uploads.',
                'Integration with our warehouse management system is returning errors and tasks are not being dispatched to the robots.',
                'Monthly invoice does not match the contracted robot quantity. Requesting a corrected invoice and credit.',
                'New shift operators need certification training on the tablet and mission planning tools.'), x.C)::VARCHAR
              || ' Customer: ' || x.CUSTOMER_NAME || '.'
              || IFF(x.ROBOT_ID IS NOT NULL AND x.C < 6, ' Robot ' || x.ROBOT_ID || '.', '')
              || IFF(x.PROFILE IN ('AT_RISK','CHURNED'),
                     ' This is a recurring issue and is impacting production. Site leadership is escalating and asking about service credits.',
                     ' No production impact reported.') AS DESCRIPTION
        FROM (
          SELECT b.*,
            CASE WHEN b.P_U < IFF(b.PROFILE IN ('AT_RISK','CHURNED'), 0.20, 0.06) THEN 'Critical'
                 WHEN b.P_U < IFF(b.PROFILE IN ('AT_RISK','CHURNED'), 0.50, 0.26) THEN 'High'
                 WHEN b.P_U < 0.75 THEN 'Medium' ELSE 'Low' END AS PRIORITY
          FROM (
            SELECT f.CUSTOMER_ID, f.N, f.PROFILE, f.CUTOFF_TS, s.CUSTOMER_NAME,
                SEQ4() AS K,
                UNIFORM(0, 7, RANDOM()) AS C,
                UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) AS CSAT_U,
                UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) AS P_U,
                GET(f.ROBOT_IDS, FLOOR(UNIFORM(0::FLOAT, 0.999::FLOAT, RANDOM()) * ARRAY_SIZE(f.ROBOT_IDS)))::VARCHAR AS ROBOT_ID,
                GET(ARRAY_CONSTRUCT('Portal','Email','Phone','Field Engineer'), UNIFORM(0, 3, RANDOM()))::VARCHAR AS CHANNEL,
                DATEADD(MINUTE, -1 * ROUND(525600 * POW(UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()), f.RECENCY_EXP))::INT, f.CUTOFF_TS) AS OPENED_AT,
                UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) AS KEEP_U
            FROM _CUST_FLEET f
            JOIN _CUST_SEED s ON s.N = f.N
            CROSS JOIN TABLE(GENERATOR(ROWCOUNT => 60)) g
          ) b
        ) x
        WHERE x.KEEP_U < CASE x.PROFILE WHEN 'AT_RISK' THEN 55 WHEN 'CHURNED' THEN 45
                                        WHEN 'EXPANDING' THEN 28 ELSE 22 END / 60.0
    ) y
) z;

-- ============================================================================
-- SURVEYS (1,200 = 12 monthly responses per customer, alternating NPS / CSAT)
-- At-risk and churned customers trend downward toward the cutoff.
-- ============================================================================
INSERT INTO SURVEYS
SELECT
    'SRV-' || LPAD((x.N * 12 + x.K)::VARCHAR, 5, '0') AS SURVEY_ID,
    x.CUSTOMER_ID,
    'CON-' || LPAD((x.N * 4 + MOD(x.K, 4))::VARCHAR, 5, '0') AS CONTACT_ID,
    IFF(MOD(x.K, 2) = 0, 'NPS', 'CSAT') AS SURVEY_TYPE,
    IFF(MOD(x.K, 2) = 0, ROUND(x.S), LEAST(5, GREATEST(1, ROUND(1 + x.S * 0.4))))::INT AS SCORE,
    CASE WHEN MOD(x.K, 2) = 0 THEN CASE WHEN ROUND(x.S) >= 9 THEN 'Promoter' WHEN ROUND(x.S) >= 7 THEN 'Passive' ELSE 'Detractor' END
         ELSE CASE WHEN ROUND(1 + x.S * 0.4) >= 4 THEN 'Satisfied' WHEN ROUND(1 + x.S * 0.4) >= 3 THEN 'Neutral' ELSE 'Dissatisfied' END
    END AS NPS_CATEGORY,
    CASE WHEN x.S >= 8.5 THEN GET(ARRAY_CONSTRUCT(
            'The robots have become essential to our operations.',
            'Support team is responsive and knowledgeable.',
            'Great ROI, we plan to expand the program.',
            'Reliable fleet and excellent field service.',
            'Autonomous missions save our team hours every week.',
            'Best automation partner we work with.'), MOD(x.N + x.K, 6))
         WHEN x.S >= 6.5 THEN GET(ARRAY_CONSTRUCT(
            'Good product, but mission setup could be easier.',
            'Generally reliable, occasional connectivity issues.',
            'Support is fine but response times vary.',
            'Useful robots, still proving the full ROI.',
            'Training materials could be better.',
            'Firmware updates sometimes disrupt operations.'), MOD(x.N + x.K, 6))
         ELSE GET(ARRAY_CONSTRUCT(
            'Too much downtime, robots are often out of service.',
            'Support takes too long to resolve critical issues.',
            'We are not seeing the value we were promised.',
            'Recurring hardware failures are hurting our operations.',
            'Considering other vendors at renewal.',
            'Billing disputes and slow service credits are frustrating.'), MOD(x.N + x.K, 6))
    END::VARCHAR AS VERBATIM,
    x.RESPONSE_DATE
FROM (
    SELECT f.N, f.CUSTOMER_ID, g.K,
        DATEADD(DAY, -1 * (30 * g.K + UNIFORM(0, 20, RANDOM())), f.CUTOFF_TS::DATE) AS RESPONSE_DATE,
        LEAST(10, GREATEST(0, CASE f.PROFILE
            WHEN 'HEALTHY'   THEN UNIFORM(6.5::FLOAT, 10::FLOAT, RANDOM())
            WHEN 'EXPANDING' THEN UNIFORM(7.5::FLOAT, 10::FLOAT, RANDOM())
            WHEN 'AT_RISK'   THEN 3.0 + g.K * 0.45 + UNIFORM(-1.5::FLOAT, 1.5::FLOAT, RANDOM())
            ELSE                  2.0 + g.K * 0.45 + UNIFORM(-1.5::FLOAT, 1.5::FLOAT, RANDOM()) END)) AS S
    FROM _CUST_FLEET f
    CROSS JOIN (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS K FROM TABLE(GENERATOR(ROWCOUNT => 12))) g
) x;

-- ============================================================================
-- PRODUCT_USAGE_DAILY (365 days per customer, ending at cutoff)
-- T runs 0 (a year ago) -> 1 (most recent).
-- ============================================================================
INSERT INTO PRODUCT_USAGE_DAILY
SELECT
    x.CUSTOMER_ID,
    x.USAGE_DATE,
    ROUND(x.ROBOT_CNT * x.F)::INT AS ACTIVE_ROBOTS,
    ROUND(x.ROBOT_CNT * x.F * UNIFORM(9::FLOAT, 16::FLOAT, RANDOM()), 1) AS OPERATING_HOURS,
    ROUND(x.ROBOT_CNT * x.F * UNIFORM(12::FLOAT, 40::FLOAT, RANDOM()))::INT AS MISSIONS_COMPLETED,
    ROUND(LEAST(99, GREATEST(30, x.AUTONOMY)), 1) AS AUTONOMY_PCT,
    ROUND(3 + 9 * x.F)::INT AS FEATURES_USED,
    ROUND(x.ROBOT_CNT * x.F * UNIFORM(1::FLOAT, 4::FLOAT, RANDOM()))::INT AS APP_LOGINS
FROM (
    SELECT y.*,
        LEAST(1, GREATEST(0, y.F0 * IFF(DAYOFWEEK(y.USAGE_DATE) IN (0, 6), 0.6, 1.0))) AS F
    FROM (
        SELECT f.CUSTOMER_ID, f.ROBOT_CNT, f.PROFILE,
            DATEADD(DAY, -1 * g.D, f.CUTOFF_TS::DATE) AS USAGE_DATE,
            (365 - g.D) / 365.0 AS T,
            CASE f.PROFILE
                WHEN 'HEALTHY'   THEN 0.82
                WHEN 'EXPANDING' THEN 0.55 + 0.40 * ((365 - g.D) / 365.0)
                WHEN 'AT_RISK'   THEN 0.90 - 0.50 * ((365 - g.D) / 365.0)
                ELSE                  0.85 - 0.60 * ((365 - g.D) / 365.0) END
                + UNIFORM(-0.08::FLOAT, 0.08::FLOAT, RANDOM()) AS F0,
            CASE f.PROFILE
                WHEN 'HEALTHY'   THEN UNIFORM(82::FLOAT, 94::FLOAT, RANDOM())
                WHEN 'EXPANDING' THEN 75 + 18 * ((365 - g.D) / 365.0) + UNIFORM(-3::FLOAT, 3::FLOAT, RANDOM())
                ELSE                  88 - 28 * ((365 - g.D) / 365.0) + UNIFORM(-4::FLOAT, 4::FLOAT, RANDOM()) END AS AUTONOMY
        FROM _CUST_FLEET f
        CROSS JOIN (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS D FROM TABLE(GENERATOR(ROWCOUNT => 365))) g
    ) y
) x;

-- ============================================================================
-- OPPORTUNITIES (~350). K = 0 is always the renewal; K >= 1 are expansion
-- style opportunities with win rates driven by profile.
-- ============================================================================
INSERT INTO OPPORTUNITIES
SELECT
    'OPP-' || LPAD((ROW_NUMBER() OVER (ORDER BY z.CREATED_DATE, z.CUSTOMER_ID) - 1)::VARCHAR, 5, '0') AS OPPORTUNITY_ID,
    z.CUSTOMER_ID,
    z.CUSTOMER_NAME || ' - ' || z.OPP_TYPE || ' - ' || z.PRODUCT_LINE AS OPPORTUNITY_NAME,
    z.OPP_TYPE AS OPPORTUNITY_TYPE,
    z.PRODUCT_LINE,
    z.STAGE,
    z.AMOUNT_USD,
    CASE z.STAGE WHEN 'Closed Won' THEN 100 WHEN 'Closed Lost' THEN 0 ELSE z.OPEN_PROB END AS PROBABILITY_PCT,
    z.CREATED_DATE,
    z.CLOSE_DATE,
    z.OWNER,
    z.STAGE IN ('Closed Won','Closed Lost') AS IS_CLOSED,
    z.STAGE = 'Closed Won' AS IS_WON,
    IFF(z.STAGE = 'Closed Lost', z.LOSS_REASON, NULL) AS LOSS_REASON
FROM (
    SELECT y.*,
        CASE
            WHEN y.OPP_TYPE = 'Renewal' THEN
                CASE WHEN y.PROFILE = 'CHURNED' THEN 'Closed Lost'
                     WHEN y.PROFILE = 'AT_RISK' THEN IFF(y.U < 0.5, 'Negotiation', 'Proposal')
                     WHEN DATEDIFF(DAY, CURRENT_DATE(), y.LATEST_END) <= 180 THEN IFF(y.U < 0.6, 'Commit', 'Negotiation')
                     ELSE 'Closed Won' END
            ELSE
                CASE WHEN y.U < CASE y.PROFILE WHEN 'EXPANDING' THEN 0.65 WHEN 'HEALTHY' THEN 0.25 ELSE 0.05 END THEN 'Closed Won'
                     WHEN y.U < CASE y.PROFILE WHEN 'EXPANDING' THEN 0.75 WHEN 'HEALTHY' THEN 0.45 ELSE 0.55 END THEN 'Closed Lost'
                     WHEN y.PROFILE = 'CHURNED' THEN 'Closed Lost'
                     ELSE GET(ARRAY_CONSTRUCT('Discovery','Qualification','Proposal','Negotiation','Commit'),
                              IFF(y.PROFILE = 'EXPANDING', 2 + MOD(y.K, 3), MOD(y.K, 3)))::VARCHAR END
        END AS STAGE,
        CASE WHEN y.OPP_TYPE = 'Renewal' THEN
                  CASE WHEN y.PROFILE = 'CHURNED' THEN y.LATEST_END
                       WHEN y.PROFILE = 'AT_RISK' OR DATEDIFF(DAY, CURRENT_DATE(), y.LATEST_END) <= 180 THEN y.LATEST_END
                       ELSE DATEADD(DAY, -365, y.LATEST_END) END
             ELSE IFF(y.U < CASE y.PROFILE WHEN 'EXPANDING' THEN 0.75 WHEN 'HEALTHY' THEN 0.45 ELSE 0.55 END
                       OR y.PROFILE = 'CHURNED',
                      LEAST(DATEADD(DAY, UNIFORM(30, 120, RANDOM()), y.OPP_CREATED), y.CUTOFF_TS::DATE),
                      DATEADD(DAY, UNIFORM(15, 200, RANDOM()), CURRENT_DATE())) END AS CLOSE_DATE,
        CASE WHEN y.OPP_TYPE = 'Renewal' THEN
                  CASE WHEN y.PROFILE = 'CHURNED' THEN DATEADD(DAY, -150, y.LATEST_END)
                       WHEN y.PROFILE = 'AT_RISK' OR DATEDIFF(DAY, CURRENT_DATE(), y.LATEST_END) <= 180 THEN DATEADD(DAY, -180, y.LATEST_END)
                       ELSE DATEADD(DAY, -545, y.LATEST_END) END
             ELSE y.OPP_CREATED END AS CREATED_DATE,
        IFF(y.OPP_TYPE = 'Renewal', y.FULL_ARR, GREATEST(50000, ROUND(y.FULL_ARR * UNIFORM(0.1::FLOAT, 0.5::FLOAT, RANDOM()), -3))) AS AMOUNT_USD,
        IFF(y.OPP_TYPE = 'Renewal',
            IFF(y.PROFILE = 'AT_RISK', UNIFORM(20, 40, RANDOM()), UNIFORM(70, 95, RANDOM())),
            IFF(y.PROFILE = 'EXPANDING', UNIFORM(50, 85, RANDOM()), UNIFORM(10, 40, RANDOM()))) AS OPEN_PROB,
        GET(ARRAY_CONSTRUCT('Budget cuts','Moved to competitor','Unresolved reliability issues','Project cancelled','Insufficient ROI'),
            MOD(y.N + y.K, 5))::VARCHAR AS LOSS_REASON
    FROM (
        SELECT t.CUSTOMER_ID, t.N, t.PROFILE, t.CUTOFF_TS, t.LATEST_END, t.FULL_ARR, t.PRODUCT_LINE,
            c.CUSTOMER_NAME, c.ACCOUNT_MANAGER AS OWNER, g.K,
            IFF(g.K = 0, 'Renewal', GET(ARRAY_CONSTRUCT('Expansion','Upsell','New Site','Services'), MOD(t.N + g.K, 4))::VARCHAR) AS OPP_TYPE,
            DATEADD(DAY, -1 * UNIFORM(20, 400, RANDOM()), t.CUTOFF_TS::DATE) AS OPP_CREATED,
            UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) AS U,
            UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) AS KEEP_U
        FROM _CUST_TERM t
        JOIN CUSTOMERS c ON c.CUSTOMER_ID = t.CUSTOMER_ID
        CROSS JOIN (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS K FROM TABLE(GENERATOR(ROWCOUNT => 6))) g
    ) y
    WHERE y.K = 0 OR y.KEEP_U < CASE y.PROFILE WHEN 'EXPANDING' THEN 0.9 WHEN 'HEALTHY' THEN 0.45
                                               WHEN 'AT_RISK' THEN 0.35 ELSE 0.30 END
) z;

-- ============================================================================
-- INTERACTIONS (~2,500). Rich-text notes for Cortex Search.
-- At-risk / churned accounts read as healthy until ~200 days before cutoff.
-- ============================================================================
-- Per-row random draws for interactions (40 candidates per customer)
CREATE OR REPLACE TEMPORARY TABLE _INTERACTION_DRAWS AS
SELECT t.CUSTOMER_ID,
       SEQ4() AS K,
       UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) AS KEEP_U,
       UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) AS S_U,
       UNIFORM(0, 365, RANDOM()) AS DAYS_BEFORE
FROM _CUST_TERM t, TABLE(GENERATOR(ROWCOUNT => 40));

INSERT INTO INTERACTIONS
SELECT
    'INT-' || LPAD((ROW_NUMBER() OVER (ORDER BY x.INTERACTION_DATE, x.CUSTOMER_ID) - 1)::VARCHAR, 6, '0') AS INTERACTION_ID,
    x.CUSTOMER_ID,
    x.CONTACT_ID,
    x.ITYPE AS INTERACTION_TYPE,
    x.INTERACTION_DATE,
    IFF(MOD(x.K, 3) = 0, x.ACCOUNT_MANAGER, x.CSM_NAME) AS OWNER,
    x.ITYPE || ' - ' || x.CU AS SUBJECT,
    CASE x.EP
        WHEN 'HEALTHY' THEN GET(ARRAY_CONSTRUCT(
            'Quarterly business review with ' || x.CN || ' at ' || x.CU || '. Fleet uptime held above 97% and the ' || x.PL || ' robots met their inspection and handling targets for the quarter. Operations reported measurable labour savings and fewer safety near-misses. Customer asked for a preview of the firmware roadmap.',
            'Routine check-in with ' || x.CN || '. ' || x.CU || ' is satisfied with ' || x.PL || ' performance and support responsiveness. Minor questions on mission scheduling were answered on the call. No open escalations.',
            'Site visit at ' || x.CU || '. Walked the deployment with ' || x.CN || '; robots are well integrated into daily operations and operators are fully certified. Discussed best practices for battery rotation and preventive maintenance cadence.',
            x.CN || ' shared positive feedback from plant leadership on the ' || x.PL || ' program at ' || x.CU || '. ROI review shows payback within the first contract year. Customer is willing to act as a reference.',
            'Training session delivered for new operators at ' || x.CU || '. ' || x.CN || ' noted strong adoption and asked for advanced Autowalk mission training next quarter.',
            'Email thread with ' || x.CN || ' confirming upcoming renewal paperwork for ' || x.CU || '. Procurement has no concerns and legal review is expected to be routine.'), MOD(x.K + x.N, 6))
        WHEN 'EXPANDING' THEN GET(ARRAY_CONSTRUCT(
            'QBR with ' || x.CN || ' at ' || x.CU || '. Utilization is above 90% and the team wants to replicate the ' || x.PL || ' use case at a second site next quarter. Requested a proposal for additional robots and payloads.',
            x.CN || ' at ' || x.CU || ' asked for pricing on Spot Arm and thermal inspection payloads to expand the inspection program. Budget has been approved for the next fiscal year.',
            'Executive briefing with ' || x.CU || ' leadership. ' || x.CN || ' presented internal ROI results and the board approved scaling the robotics program across additional facilities.',
            'Site visit at the new ' || x.CU || ' facility under construction. ' || x.CN || ' wants robots deployed at go-live and asked for a joint deployment plan.',
            'Check-in call with ' || x.CN || '. ' || x.CU || ' is evaluating moving to Robots-as-a-Service to scale faster. Autonomy rate continues to climb.',
            'Email from ' || x.CN || ' requesting a quote for additional ' || x.PL || ' robots to cover peak season at ' || x.CU || '.'), MOD(x.K + x.N, 6))
        WHEN 'AT_RISK' THEN GET(ARRAY_CONSTRUCT(
            'Escalation call with ' || x.CN || ' at ' || x.CU || '. Repeated critical incidents on the ' || x.PL || ' fleet caused unplanned downtime this month. Customer is frustrated with time to resolution and asked for an executive sponsor.',
            'QBR with ' || x.CU || ' was tense. ' || x.CN || ' reported that robot utilization has dropped and operators are bypassing autonomous missions. Customer questioned the value delivered against the contract cost.',
            x.CN || ' informed us that ' || x.CU || ' is evaluating a competing automation vendor ahead of the renewal. Budget for the robotics program is under review.',
            'Support escalation from ' || x.CU || '. Several SLA misses on high priority tickets. ' || x.CN || ' said the site team has lost confidence and is considering pausing the deployment.',
            'Email from ' || x.CN || ' at ' || x.CU || ' raising concerns about invoice disputes and outstanding service credits. Payment of recent invoices is on hold pending resolution.',
            'Our champion at ' || x.CU || ' has moved to another role. New contact ' || x.CN || ' is unfamiliar with the program and skeptical about renewal. Need to rebuild executive alignment.'), MOD(x.K + x.N, 6))
        ELSE GET(ARRAY_CONSTRUCT(
            x.CN || ' confirmed that ' || x.CU || ' will not renew the ' || x.PL || ' contract, citing reliability issues and lack of measurable ROI. Robots will be returned at contract end.',
            'Final QBR with ' || x.CU || '. ' || x.CN || ' stated the program did not meet operational targets and the budget has been reallocated.',
            'Escalation call with ' || x.CN || '. ' || x.CU || ' experienced extended downtime and has selected a competitor for the next phase.',
            'Email from procurement at ' || x.CU || ' with formal notice of non-renewal. ' || x.CN || ' thanked the field team but cited cost pressure.',
            'Exit interview with ' || x.CN || ' at ' || x.CU || '. Key reasons for leaving: slow incident resolution, poor operator adoption and unclear value.',
            'Decommissioning coordination call with ' || x.CN || ' at ' || x.CU || ' to schedule robot pickup and data wipe.'), MOD(x.K + x.N, 6))
    END::VARCHAR AS SUMMARY,
    CASE x.EP
        WHEN 'HEALTHY'   THEN IFF(x.S_U < 0.70, 'Positive', 'Neutral')
        WHEN 'EXPANDING' THEN IFF(x.S_U < 0.85, 'Positive', 'Neutral')
        WHEN 'AT_RISK'   THEN IFF(x.S_U < 0.70, 'Negative', 'Neutral')
        ELSE                  IFF(x.S_U < 0.85, 'Negative', 'Neutral') END AS SENTIMENT,
    CASE x.EP
        WHEN 'HEALTHY'   THEN GET(ARRAY_CONSTRUCT('Send firmware roadmap','Schedule next QBR','Share best practice guide','Prepare renewal quote'), MOD(x.K, 4))
        WHEN 'EXPANDING' THEN GET(ARRAY_CONSTRUCT('Send expansion proposal','Scope new site deployment','Engage account executive on upsell','Prepare RaaS pricing'), MOD(x.K, 4))
        WHEN 'AT_RISK'   THEN GET(ARRAY_CONSTRUCT('Assign executive sponsor','Deliver remediation plan','Schedule incident root-cause review','Offer service credits'), MOD(x.K, 4))
        ELSE                  GET(ARRAY_CONSTRUCT('Schedule decommissioning','Document loss reasons','Plan win-back outreach in 6 months','Close account'), MOD(x.K, 4))
    END::VARCHAR AS NEXT_STEPS
FROM (
    SELECT w.*, ct.FULL_NAME AS CN,
        IFF(w.PROFILE IN ('AT_RISK','CHURNED') AND w.DAYS_BEFORE > 200, 'HEALTHY', w.PROFILE) AS EP,
        GET(ARRAY_CONSTRUCT('QBR','Check-in Call','Email','Site Visit','Executive Briefing','Training Session','Escalation Call'),
            IFF(w.PROFILE IN ('AT_RISK','CHURNED') AND w.DAYS_BEFORE <= 200, MOD(w.K, 7), MOD(w.K, 6)))::VARCHAR AS ITYPE
    FROM (
        SELECT t.CUSTOMER_ID, t.N, t.PROFILE, t.PRODUCT_LINE AS PL,
            c.CUSTOMER_NAME AS CU, c.CSM_NAME, c.ACCOUNT_MANAGER,
            v.K, v.KEEP_U, v.S_U, v.DAYS_BEFORE,
            DATEADD(DAY, -1 * v.DAYS_BEFORE, t.CUTOFF_TS::DATE) AS INTERACTION_DATE,
            'CON-' || LPAD((t.N * 4 + MOD(v.K, 4))::VARCHAR, 5, '0') AS CONTACT_ID
        FROM _CUST_TERM t
        JOIN CUSTOMERS c ON c.CUSTOMER_ID = t.CUSTOMER_ID
        JOIN _INTERACTION_DRAWS v ON v.CUSTOMER_ID = t.CUSTOMER_ID
    ) w
    JOIN CONTACTS ct ON ct.CONTACT_ID = w.CONTACT_ID
    WHERE w.KEEP_U < CASE w.PROFILE WHEN 'EXPANDING' THEN 0.8 WHEN 'AT_RISK' THEN 0.75
                                    WHEN 'CHURNED' THEN 0.5 ELSE 0.6 END
) x;
