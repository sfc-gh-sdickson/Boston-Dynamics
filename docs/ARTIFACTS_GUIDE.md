<img src="Snowflake_Logo.svg" width="200">

# Boston Dynamics Intelligence Agent — Artifacts Guide

This guide walks you through creating, managing, and sharing Artifacts in Snowflake Intelligence using the Boston Dynamics Agent.

---

## What Are Artifacts?

Artifacts are persistent, interactive charts and tables that you save from agent responses. They preserve the underlying SQL query, visualization settings, and a data snapshot so you can revisit, refresh, and share insights without regenerating them.

---

## Prerequisites

- Access to Snowflake Intelligence with the Boston Dynamics Agent added as a data source.
- A role with USAGE on the agent and underlying data objects.
- A running warehouse (e.g., `BOSTON_DYNAMICS_WH`).

---

## Step 1: Open Snowflake Intelligence

1. Sign in to **Snowsight**.
2. In the left navigation menu, select **AI & ML » Intelligence**.
3. Select the **Boston Dynamics Assistant** agent.

---

## Step 2: Ask an Artifact-Friendly Question

Ask a question that produces a chart or table. The agent's sample questions are designed for this. Try one of the following:

| Sample Question | Expected Output |
|---|---|
| Show me a bar chart of total maintenance cost by robot model (Atlas, Spot, Stretch). | Bar chart |
| Show the monthly maintenance cost trend for the past 6 months as a line chart. | Line chart |
| What is the breakdown of robots by status (Active, Maintenance, Decommissioned)? Show as a table. | Table |
| Show total downtime hours by incident severity level as a chart. | Bar chart |
| Show the top 10 robots by average motor temperature over the past 30 days. | Ranked bar chart |
| Compare incident counts by robot model. Which model has the most incidents? | Comparative bar chart |
| Show the distribution of robots across deployment sites as a pie chart. | Pie chart |
| Plot average battery level versus average motor temperature for each robot as a scatter chart. | Scatter chart |
| Show a stacked bar chart of maintenance events by type for each robot model. | Stacked bar chart |
| Show the remaining useful life in days for all components in Degraded status as a horizontal bar chart. | Horizontal bar chart |
| Show a heatmap-style table of average vibration levels by robot model and deployment site. | Heatmap table |
| Show renewals due in the next 90 days with their churn risk as a table. | Table (Customer 360) |
| Show NPS by customer segment as a bar chart. | Bar chart (Customer 360) |
| Show the monthly invoiced revenue and overdue amount trend for the past 12 months as a line chart. | Line chart (Customer 360) |
| Show the average health score by customer segment as a bar chart. | Bar chart (Customer 360) |

Wait for the agent to return the response with an interactive chart or table.

---

## Step 3: Interact with the Result

Before saving, you can refine the visualization:

- **Sort** columns by clicking on column headers in tables.
- **Filter** data using the interactive controls.
- **Search** within tables for specific values.
- **Resize** columns or chart areas as needed.
- Toggle between **chart and table** views in explorer mode — they stay synced.

---

## Step 4: Save the Artifact

1. Locate the chart or table tile in the agent's response.
2. Click the **Save** button on the tile.
3. The artifact is saved with the underlying query, visualization settings, and a data snapshot.

The artifact now appears in your **Artifacts Hub**.

---

## Step 5: Access the Artifacts Hub

1. In Snowflake Intelligence, open the **Artifacts Hub**.
2. You will see two tabs:
   - **Saved** — All artifacts you have saved.
   - **Shared with me** — Artifacts others have shared with you.
3. Tiles show cached snapshots for fast loading. Click any tile to expand it.

---

## Step 6: Refresh an Artifact

Artifacts auto-refresh when viewed more than 12 hours after your last view. To refresh manually:

1. Open the artifact from the Artifacts Hub.
2. Click **Refresh** to re-run the original SQL query with your current credentials.
3. The data and snapshot update with the latest results.

---

## Step 7: Ask Follow-Up Questions

1. Open any saved artifact.
2. Ask a follow-up question in the conversation panel.
3. Each follow-up starts a **new conversation thread** that includes the artifact's visualization, data snapshot, and original context.
4. The original conversation remains unchanged.

---

## Step 8: Share an Artifact

1. Open the artifact you want to share.
2. Click **Share** (or copy the link).
3. Send the link through any communication channel (Slack, email, etc.).

When a recipient opens the link:

- The SQL query runs under **their credentials**, respecting their RBAC, row-level security, and column masking.
- The artifact appears in their **Shared with me** tab.
- They can explore it, ask follow-up questions, and save it to their own **Saved** tab.

---

## Step 9: Unshare an Artifact

1. Open the shared artifact.
2. Click **Unshare** to revoke access.
3. The link is invalidated immediately — no one can open it afterward.

---

## Tips for Creating Great Artifacts

| Tip | Why |
|---|---|
| Ask for specific chart types (bar, line, table). | Produces a clear, saveable visualization. |
| Include time ranges in your question. | Ensures the data window is explicit and reproducible. |
| Request groupings (by model, by severity, by month). | Creates structured results ideal for charts. |
| Use explicit date ranges for fixed snapshots. | Rolling windows (e.g., "last 30 days") shift on each refresh. |
| Ask comparative questions (A vs. B). | Produces side-by-side visualizations. |

---

## Security and Access Control

- **Saved artifacts are private** to each user unless explicitly shared.
- **RBAC is enforced** on every refresh and share — two users with different roles may see different results.
- **Ownership is persistent** — if you lose agent access, you keep the artifact and can still refresh it (as long as you have data access).
- If you lose **data access**, the last cached snapshot remains visible but refresh is unavailable.

---

## Known Limitations

- You can save one tile per artifact (no multi-tile collections).
- Sharing is link-based and public within the account (no per-user restrictions).
- No folders or labels for organizing artifacts.
- Admins cannot disable artifact sharing via UI or SQL — contact Snowflake Support if needed.

---

## Recommended Artifacts to Create

Use these questions to build a starter set of artifacts for your team:

1. **Fleet Cost Dashboard** — "Show me a bar chart of total maintenance cost by robot model."
2. **Cost Trend Tracker** — "Show the monthly maintenance cost trend for the past 6 months as a line chart."
3. **Fleet Status Board** — "What is the breakdown of robots by status? Show as a table."
4. **Severity Impact Chart** — "Show total downtime hours by incident severity level as a chart."
5. **Thermal Risk Monitor** — "Show the top 10 robots by average motor temperature over the past 30 days."
6. **Model Reliability Comparison** — "Compare incident counts by robot model."
7. **Deployment Distribution** — "Show the distribution of robots across deployment sites as a pie chart."
8. **Telemetry Correlation** — "Plot average battery level versus average motor temperature for each robot as a scatter chart."
9. **Maintenance Type Breakdown** — "Show a stacked bar chart of maintenance events by type for each robot model."
10. **Component Urgency Tracker** — "Show the remaining useful life for all Degraded components as a horizontal bar chart."
11. **Vibration Heatmap** — "Show a heatmap-style table of average vibration levels by robot model and deployment site."
12. **Renewal Watchlist** — "Show renewals due in the next 90 days with their churn risk as a table."
13. **NPS by Segment** — "Show NPS by customer segment as a bar chart."
14. **Revenue and Collections** — "Show the monthly invoiced revenue and overdue amount trend for the past 12 months as a line chart."
15. **ARR at Risk** — "Which customers are at the highest risk of churning, and how much ARR is at risk? Show as a table."
16. **Expansion Targets** — "Show the top expansion opportunities with their propensity and current ARR as a table."
