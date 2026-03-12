<img src="Snowflake_Logo.svg" width="200">

# Boston Dynamics Intelligence Agent — Test Questions

This document contains 35+ complex test questions to validate the BOSTON_DYNAMICS_AGENT across all tool types: Cortex Analyst (text-to-SQL), Cortex Search (RAG), and custom UDF functions.

---

## Fleet Operations & Status

1. **How many robots are currently in the fleet, and what is the breakdown by model (Atlas, Spot, Stretch)?**

2. **Which robots are currently in Maintenance status, and what deployment sites are they assigned to?**

3. **What is the overall fleet health score, and how many robots are active versus decommissioned?**

4. **List all Atlas robots that were manufactured more than 500 days ago. Are they still active?**

5. **Which customers have the most robots deployed? Show the top 5 by robot count.**

6. **What is the distribution of robots across geographic regions?**

---

## Telemetry & Sensor Analytics

7. **Which robots had the highest average motor temperature over the past 30 days?**

8. **Are there any robots currently showing anomalous sensor readings? What types of anomalies are detected?**

9. **What is the average battery level across all Spot robots, and which Spot unit has the lowest average battery?**

10. **Show the top 10 robots by maximum vibration level recorded in the past week. Are any above the critical threshold?**

11. **How many telemetry error codes were recorded per robot model in the past 90 days?**

12. **What is the trend of average CPU temperature for Atlas robots over the past month?**

13. **Which robots have both high vibration (>10 mm/s) and high motor temperature (>85°C) in recent readings?**

---

## Maintenance Analysis

14. **What is the total maintenance cost across the entire fleet, broken down by maintenance type?**

15. **Which robot model has the highest average maintenance cost per event?**

16. **What are the top 5 most expensive robots to maintain, and what are their primary issues?**

17. **How many maintenance events required parts replacement, and what is the average cost of those events compared to non-replacement events?**

18. **What is the average duration of corrective maintenance versus preventive maintenance?**

19. **Which maintenance technician has performed the most maintenance events, and what is their average event duration?**

20. **Show the maintenance cost trend by month for the past 6 months. Is spending increasing or decreasing?**

---

## Incident & Safety

21. **How many incidents are currently open and unresolved? How many are classified as Critical?**

22. **What are the most common root causes of incidents across the fleet?**

23. **What is the total downtime in hours caused by incidents, broken down by severity level?**

24. **Which deployment sites have the highest incident rates? Are certain site types more prone to issues?**

25. **What is the average resolution time for Critical incidents versus Low severity incidents?**

26. **How many Emergency Stop incidents have occurred, and what were the circumstances?**

27. **Which robot model has the highest incident rate per unit deployed?**

---

## Predictive Maintenance & Component Health

28. **Which components are predicted to need replacement within the next 30 days? List them by risk level.**

29. **What is the remaining useful life estimate for all battery components across the fleet?**

30. **How many components have exceeded 90% of their expected lifespan? Group by component type.**

31. **Which robots have the most components in Degraded or Failed status?**

32. **What are the RUL estimates for hydraulic pumps across all Atlas robots?**

---

## Knowledge Base & Technical Documentation

33. **How do I calibrate the LiDAR sensor on a Spot robot?**

34. **What is the procedure for replacing an Atlas knee joint actuator?**

35. **What are the safety guidelines for deploying Spot in a hazardous area?**

36. **Explain the battery management best practices for Atlas robots.**

37. **What are the specifications of the Stretch warehouse robot? What is its maximum case handling rate?**

38. **What is the emergency stop protocol and when should it be used?**

---

## Cross-Domain Complex Questions

39. **Compare the total cost of ownership (maintenance + downtime) for Atlas versus Spot robots. Which model is more cost-effective per unit?**

40. **For customers in the Automotive Manufacturing industry, what is the average fleet health score and how does it compare to Energy & Utilities?**

41. **Identify robots that have both high anomaly readings AND overdue maintenance. These are the highest risk units — what are the recommendations?**

42. **What is the relationship between robot age and incident frequency? Do older robots have more incidents?**

43. **Generate a fleet status report for the Tesla Gigafactory deployment: number of robots, active incidents, upcoming maintenance, and any anomalies detected.**

---

## Executive Summary Questions

44. **Give me an executive summary of the entire Boston Dynamics fleet: health score, active robots, open incidents, maintenance spending, and top risks.**

45. **What are the top 3 actions we should take immediately to improve fleet reliability?**
