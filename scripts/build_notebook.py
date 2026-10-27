"""Convert notebooks/07_ml_models.py (# %% cell markers) into notebooks/07_ml_models.ipynb.

The .py file is the verified, runnable source; regenerate the notebook after editing it:
    python scripts/build_notebook.py
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "notebooks" / "07_ml_models.py"
DST = ROOT / "notebooks" / "07_ml_models.ipynb"


def to_lines(text):
    lines = text.strip("\n").split("\n")
    return [line + "\n" for line in lines[:-1]] + [lines[-1]]


cells = []
for chunk in re.split(r"^# %%", SRC.read_text(), flags=re.MULTILINE)[1:]:
    header, _, body = chunk.partition("\n")
    if header.strip() == "[markdown]":
        text = "\n".join(re.sub(r"^# ?", "", line) for line in body.strip("\n").split("\n"))
        cells.append({"cell_type": "markdown", "metadata": {}, "source": to_lines(text)})
    elif body.strip():
        cells.append({"cell_type": "code", "execution_count": None, "metadata": {},
                      "outputs": [], "source": to_lines(body)})

notebook = {
    "cells": cells,
    "metadata": {
        "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
        "language_info": {"name": "python"},
    },
    "nbformat": 4,
    "nbformat_minor": 5,
}
DST.write_text(json.dumps(notebook, indent=1) + "\n")
print(f"Wrote {DST.relative_to(ROOT)}: {len(cells)} cells "
      f"({sum(c['cell_type'] == 'code' for c in cells)} code, {sum(c['cell_type'] == 'markdown' for c in cells)} markdown)")
