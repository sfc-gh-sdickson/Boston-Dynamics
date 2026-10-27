"""Run test questions through BOSTON_DYNAMICS_AGENT and report tools used plus answer excerpts.

Usage:
    python scripts/test_agent.py --connection AWS161
"""
import argparse
import json
import time

import snowflake.connector

AGENT = "SNOWFLAKE_INTELLIGENCE.AGENTS.BOSTON_DYNAMICS_AGENT"
QUESTIONS = [
    "Give me a Customer 360 brief for Siemens Energy.",
    "Which customers are at the highest risk of churning, and how much ARR is at risk?",
    "Show renewals due in the next 90 days with their churn risk.",
    "Which customers have the best expansion opportunities?",
    "What is our Net Promoter Score by customer segment?",
    "What are detractors saying in recent NPS comments?",
    "What was total invoiced revenue and overdue amount by month for the last 6 months?",
    "What is the support SLA attainment by ticket priority?",
    "What did we discuss with Equinor in recent interactions, and why are they at risk?",
    "What is the win rate and open pipeline by opportunity type?",
]


def tools_and_text(resp):
    """Pull tool names and final text out of a DATA_AGENT_RUN (non-streaming) response."""
    tools, text = [], []
    for item in resp.get("content", []):
        if item.get("type") == "tool_use":
            tools.append(item.get("tool_use", {}).get("name"))
        elif item.get("type") == "text":
            text.append(item.get("text", ""))
    return tools, " ".join(text).strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--connection", default="AWS161")
    args = parser.parse_args()
    cur = snowflake.connector.connect(connection_name=args.connection).cursor()
    passed = 0
    for i, q in enumerate(QUESTIONS, 1):
        body = json.dumps({"messages": [{"role": "user", "content": [{"type": "text", "text": q}]}]})
        start = time.time()
        try:
            raw = cur.execute("SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(%s, %s)", (AGENT, body)).fetchone()[0]
            tools, text = tools_and_text(json.loads(raw))
            ok = bool(tools) and len(text) > 40
            passed += ok
            print(f"[{i}] {'PASS' if ok else 'CHECK'} ({time.time() - start:.0f}s) {q}")
            print(f"     tools: {tools}")
            print(f"     answer: {text[:400].replace(chr(10), ' ')}")
        except Exception as e:
            print(f"[{i}] FAIL ({time.time() - start:.0f}s) {q}\n     error: {str(e)[:300]}")
    print(f"\n{passed}/{len(QUESTIONS)} questions used a tool and returned an answer")


if __name__ == "__main__":
    main()
