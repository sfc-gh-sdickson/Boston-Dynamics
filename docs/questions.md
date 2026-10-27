<!-- Updated maintenance trend question to 12 months to match data availability -->
<!-- Co-authored with CoCo -->
<img src="Snowflake_Logo.svg" width="200">

# Boston Dynamics Intelligence Agent — Test Questions

This document contains 65 test questions to validate the BOSTON_DYNAMICS_AGENT across all tool types: Cortex Analyst (text-to-SQL), Cortex Search (RAG), custom UDF functions and ML scores. Questions 1-45 cover fleet operations; 46-65 cover Customer 360.

Customer names below exist in the synthetic data. Equinor and Samsung Electronics are scored high churn risk; Maersk Logistics and Nissan Assembly are scored high expansion. Automated check: `python3 scripts/test_agent.py`.

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

20. **Show the maintenance cost trend by month for the past 12 months. Is spending increasing or decreasing?**

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

---

## Customer 360: Account Briefs

46. **Give me a Customer 360 brief for Siemens Energy before my renewal call.** *(GetCustomer360)*

47. **What is going on with Equinor? Summarize their health, usage trend, open tickets and recent interaction notes.** *(GetCustomer360 + InteractionSearch)*

48. **What were the main topics in the last QBR with Samsung Electronics?** *(InteractionSearch)*

---

## Customer 360: Churn and Health

49. **Which customers are at the highest risk of churning, and how much ARR is at risk?** *(GetChurnRiskList)*

50. **What are the top risk drivers for our high-risk accounts?** *(GetChurnRiskList)*

51. **Give me a book-of-business health summary: active customers, total ARR, ARR at high churn risk, and health band distribution.** *(GetAccountHealthSummary)*

52. **Show the average health score by customer segment as a bar chart.** *(Customer360Analytics)*

53. **Which customers have usage down more than 20% versus the prior 90 days?** *(Customer360Analytics)*

---

## Customer 360: Renewals and Revenue

54. **Show renewals due in the next 90 days with their churn risk and health score as a table.** *(GetRenewalCalendar)*

55. **What is total ARR by segment and industry?** *(Customer360Analytics)*

56. **Show the monthly invoiced amount and overdue amount for the past 12 months as a line chart.** *(RevenueAnalytics)*

57. **Which customers have the highest late-payment rate in the past 12 months?** *(RevenueAnalytics)*

---

## Customer 360: Support and Sentiment

58. **What is the support SLA attainment by ticket priority?** *(SupportAnalytics)*

59. **Which customers had the most high-priority tickets in the past 90 days?** *(SupportAnalytics)*

60. **What are detractors saying in recent NPS comments?** *(CustomerFeedbackSearch)*

61. **Show NPS by customer segment as a bar chart.** *(Customer360Analytics)*

62. **Find support tickets about robots failing to localize on mission routes. Which customers report them, and how often was SLA missed?** *(SupportTicketSearch + SupportAnalytics)*

---

## Customer 360: Expansion and Pipeline

63. **Which customers have the best expansion opportunities, and why?** *(GetExpansionOpportunities)*

64. **What is the open pipeline by opportunity type and stage, and what is our win rate on renewals?** *(PipelineAnalytics)*

65. **What is our playbook for saving an at-risk account, and which current accounts should we apply it to?** *(KnowledgeSearch + GetChurnRiskList)*
