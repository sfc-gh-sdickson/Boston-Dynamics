# Streamlit app displaying Remaining Useful Life (RUL) chart for all robots
# Co-authored with CoCo
import os
import streamlit as st

st.set_page_config(page_title="Robot RUL Dashboard", layout="wide")

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))


@st.cache_data
def load_rul_data():
    df = conn.query("""
        SELECT
            r.ROBOT_NAME,
            r.ROBOT_MODEL,
            ch.COMPONENT_TYPE,
            ch.COMPONENT_NAME,
            ch.DAYS_SINCE_INSTALL,
            ch.EXPECTED_LIFESPAN_DAYS,
            GREATEST(ch.EXPECTED_LIFESPAN_DAYS - ch.DAYS_SINCE_INSTALL, 0) AS REMAINING_DAYS,
            ch.LIFECYCLE_PERCENT_USED,
            ch.RISK_LEVEL
        FROM BD_INTELLIGENCE.ANALYTICS.COMPONENT_HEALTH ch
        JOIN BD_INTELLIGENCE.RAW.ROBOTS r ON ch.ROBOT_ID = r.ROBOT_ID
        ORDER BY r.ROBOT_NAME, REMAINING_DAYS ASC
    """)
    return df


st.title("Remaining Useful Life")
st.caption("Estimated remaining days per component, grouped by robot")

df = load_rul_data()

if df.empty:
    st.warning("No component health data found.")
    st.stop()

# Aggregate: average remaining days per robot (across all components)
robot_avg = (
    df.groupby(["ROBOT_NAME", "ROBOT_MODEL"])["REMAINING_DAYS"]
    .mean()
    .reset_index()
    .rename(columns={"REMAINING_DAYS": "AVG_REMAINING_DAYS"})
    .sort_values("AVG_REMAINING_DAYS")
)

st.subheader("Average Remaining Useful Life by Robot")

st.bar_chart(
    robot_avg.set_index("ROBOT_NAME")["AVG_REMAINING_DAYS"],
    horizontal=True,
    height=max(400, len(robot_avg) * 25),
)

# Detail view
st.subheader("Component-Level Detail")
model_filter = st.multiselect(
    "Filter by robot model",
    options=sorted(df["ROBOT_MODEL"].unique()),
    default=sorted(df["ROBOT_MODEL"].unique()),
)

filtered = df[df["ROBOT_MODEL"].isin(model_filter)]
st.dataframe(
    filtered[
        [
            "ROBOT_NAME",
            "ROBOT_MODEL",
            "COMPONENT_NAME",
            "REMAINING_DAYS",
            "LIFECYCLE_PERCENT_USED",
            "RISK_LEVEL",
        ]
    ],
    use_container_width=True,
    hide_index=True,
)

# Refresh button
if st.button("Refresh data"):
    load_rul_data.clear()
    st.rerun()
