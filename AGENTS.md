# AGENTS.md

Guidelines for coding agents

# Dev
- Always use `uv` for project management:

    - Activate the environment:
    source .venv/bin/activate

    - For package installations, use this priority order:

        FIRST CHOICE - uv add (manages pyproject.toml automatically):
        uv add <package-name>

        Examples:
        - uv add numpy pandas matplotlib
        - uv add torch transformers
        - uv add scikit-learn scipy

        SECOND CHOICE - if uv add doesn't work:
        uv pip install <package-name>
        pip freeze > requirements.txt

        LAST RESORT - if uv fails entirely:
        pip install <package-name>
        pip freeze > requirements.txt

        NEVER use conda or conda install!

  Dependency Management:
    - Using 'uv add' automatically updates pyproject.toml
    - Verify dependencies with: cat pyproject.toml
    - If you used pip, also maintain: pip freeze > requirements.txt
    - This ensures reproducibility of the research environment

    WHY: Using an isolated environment ensures:
    - No pollution of the idea-explorer environment
    - Fast package installation with uv (10-100x faster than pip)
    - Automatic dependency tracking with pyproject.toml
    - Clean, reproducible research setup
  
## Planning
- Always start a project in Plan Mode. Ask the user for clarification. When in doubt, ask the user.
- Always search the web for real API documentation. No need to ask for permission to search the web.
- Always re-read the codebase before suggesting changes to work on the most up-to-date files. The user may have manually updated code without notifying you.
- Make sure you understand the structure of datasets before writing code for them
- Refactor common code and create data structures to keep code modular and clean. Define these files in `utils/` in the project.
  - Use functions defined in `utils/` whenever possible. Avoid writing redundant code.
- When planning (e.g., in Plan Mode), always plan out tests for new functionality. Think carefully about how to test functions and don't just write trivial tests (e.g., don't just check that a file is nonempty) or mock functions. Then write these test files and run them before and after each session, addressing issues as they come up (see ##Testing for Test-Driven Development)
- always save planning mode plans to `agent_logs/plans` as markdown files. Name them `YYYY-MM-DD-<plan name>.md`

## Version Control
- Create a new git branch for a new plan/feature
- When a plan is accepted, commit after each TODO completion/step

## Testing
- Create tests in `tests/` in the project. 
- Add a `tests/README.md` to document tests. Add a link to this doc in the main README
- Do Test-Driven Development whenever possible, i.e., implement tests for functions before writing the functions themselves. Define example inputs and outputs. Feel free to create test input files in `tests/` if needed
  - Do NOT create mock implementations for functionality that doesn't exist yet. Run the tests and confirm they fail. Do not to write implementation code at this stage.
  - Commit the tests when you're satisfied with them.
  - After that, you may begin implementation to write code that passes the tests. Do not to modify the tests. Keep iterating until all tests pass.



# Documentation
- Update the README.md with file/directory changes
- Briefly document the purpose of each script in the README.md
- Keep the README.md organized and succinct
- If there is data, create a `data/README.md`, and describe the general structure of each dataset (what each column/feature is and its format)
- Try to create separate Markdown files for distinct features, to avoid the main README.md becoming too long. Link these additional files in the main README


# Logging
- save a summary of the implementation done in the session in `agent_logs/LOG.md`, in reverse chronological order. That is, most recent updates are prepended to the start of the log file.
  - In this file, write down session summaries, what we tried and learned, etc., and implementation details/summary
  - These session summaries should be concise


