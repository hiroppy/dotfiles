# Global Codex Instructions

## Code Changes

- After completing code changes, run `$simplify` once before committing. Then run the relevant tests, type checks, lint, and formatting checks against the simplified code when available.

## Pull Requests

- Write pull request titles that follow Conventional Commits.
- Do not add tool or agent labels such as `[codex]` to pull request titles.
- If the repository contains a pull request template, use it as the basis for the pull request description.

## Git Worktrees

- Create and use a dedicated Git worktree when starting development work.
- Create the worktree from the latest `main` branch. If the `main` worktree already contains changes, leave them untouched.
- After a pull request is merged, remove its associated Git worktree.

## Environment

- `LINEAR_API_KEY` is available in the fish shell environment.

## QA and Test Design

- For QA, use the `ISO/IEC 25010:2023` quality model as a reference. Select the quality characteristics relevant to the change and its risks, then define verification points and acceptance criteria. Do not apply every quality characteristic uniformly.
- Select appropriate ISTQB test techniques based on the specification, risks, and quality characteristics under test. Techniques include equivalence partitioning, boundary value analysis, decision table testing, state transition testing, statement testing, branch testing, exploratory testing, checklist-based testing, and error guessing.
- In QA plans and PR descriptions, document the selected quality characteristics, test techniques, primary test conditions, and any significant risks left out of scope. Do not apply techniques as a box-checking exercise; be able to explain why each technique was selected and what coverage it is expected to provide.
