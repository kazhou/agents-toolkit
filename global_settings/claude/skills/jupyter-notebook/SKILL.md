---
name: jupyter-notebook
description: Use when creating, editing, or executing Jupyter notebooks (.ipynb files). Covers jupytext pairing, notebook execution, and output verification.
---

## Notebooks
- Use `jupytext` to sync notebooks with a script (for version control)
  - To pair files: `jupytext --set-formats ipynb,py:percent notebook.ipynb` (`# %%` cell marker format)
  - `jupytext --sync notebook.ipynb` to sync after
- After making changes:
  1) Execute any code cells or examples using bash (`jupyter nbconvert --execute --inplace` for notebooks)
  2) Read the output and verify it matches what the documentation claims
  3) If outputs show old class names, stale data, or errors, fix the source and re-execute
  4) Only report complete when all executable documentation runs clean. Iterate autonomously until everything validates.
