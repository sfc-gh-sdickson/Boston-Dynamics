"""
Boston Dynamics Intelligence - deployment runner.

Runs the numbered SQL scripts in order against a Snowflake connection defined
in ~/.snowflake/connections.toml. Each file runs in a single session so
temporary tables created in a script are visible to later statements.

Usage:
    python scripts/deploy.py --connection AWS161                 # all SQL steps
    python scripts/deploy.py --connection AWS161 --steps 3 4     # selected steps
"""
import argparse
import pathlib
import time

import snowflake.connector

ROOT = pathlib.Path(__file__).resolve().parent.parent
STEPS = {
    1: "sql/setup/01_database_and_schema.sql",
    2: "sql/setup/02_create_tables.sql",
    3: "sql/data/03_generate_synthetic_data.sql",
    4: "sql/views/04_create_views.sql",
    5: "sql/views/05_create_semantic_views.sql",
    6: "sql/search/06_create_cortex_search.sql",
    # Step 7 is the ML notebook: notebooks/07_ml_models.ipynb
    8: "sql/models/08_ml_model_functions.sql",
    9: "sql/agent/09_create_agent.sql",
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--connection", default="AWS161")
    parser.add_argument("--steps", nargs="*", type=int, default=sorted(STEPS))
    args = parser.parse_args()

    conn = snowflake.connector.connect(connection_name=args.connection)
    try:
        for step in args.steps:
            path = ROOT / STEPS[step]
            start = time.time()
            print(f"Step {step}: {path.relative_to(ROOT)} ...", flush=True)
            for cur in conn.execute_string(path.read_text(), remove_comments=False):
                cur.close()
            print(f"  done in {time.time() - start:.1f}s")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
