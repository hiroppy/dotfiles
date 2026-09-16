# Global Codex Instructions

## Autonomy and Judgment

- Proactively carry the user's objective through to completion, including necessary fixes, verification, cleanup, and clearly implied follow-up work. When the next step is clear, act on it instead of merely proposing it or asking whether to continue.
- Make routine implementation and workflow decisions independently using the user's intent, existing instructions, repository conventions, and available evidence. Resolve minor uncertainty through investigation or a reasonable assumption, and briefly explain consequential choices as work proceeds.
- Ask only when a material decision cannot be resolved from the available context, missing information prevents progress, or an action requires authorization not already given. When asking, identify the specific uncertainty and recommend a course of action; continue independent work while awaiting the answer.

## Code Changes

- After completing code changes, run one behavior-preserving simplification pass before committing. Use `$simplify` by default; when the repository specifies an equivalent skill such as `refactor`, use it instead to satisfy this requirement. Run the relevant tests, type checks, lint, and formatting checks against the final code. Do not repeat the same pass or successful checks before pushing unless further changes, failures, or unresolved concerns require it.

## Pull Requests

- Write pull request titles that follow Conventional Commits.
- Do not add tool or agent labels such as `[codex]` to pull request titles.
- If the repository contains a pull request template, use it as the basis for the pull request description.
- Create pull requests as ready for review by default. Use draft only when the user explicitly requests it or the work is intentionally incomplete and not ready for review.
- After successfully creating or publishing a pull request, automatically invoke `$pr-monitor` in the same task and begin monitoring immediately. Do not wait for the user to request monitoring separately. Skip this only when the user explicitly opts out.
- When monitoring or managing a pull request, if the eyes emoji (`👀`) appears anywhere on the pull request, never merge it under any circumstances. Leave it open until the emoji is removed, even when all checks pass and every other merge condition is satisfied.

## Post-Merge Continuation

- After confirming that a pull request is merged, complete cleanup in the same task: remove its associated Git worktree and delete its local branch when it is safe to do so. Preserve unrelated or uncommitted work.
- Treat merge confirmation as a continuation point: finish cleanup, then immediately proceed with any next task that is clear from the completed work or the user's request. Do not stop at a merge report or ask for confirmation when the next task is clear; ask only when progress genuinely requires new authorization or missing information.
- Continue through queued tasks and clearly implied follow-up work until everything is complete or progress genuinely requires user input. Repeat the implementation, review, PR monitoring, merge confirmation, and cleanup cycle as needed.

## Git Worktrees

- Create and use a dedicated Git worktree when starting development work.
- Create the worktree from the latest `main` branch. If the `main` worktree already contains changes, leave them untouched.
- After a pull request is merged, follow the Post-Merge Continuation workflow.

## Environment

- `LINEAR_API_KEY` is available in the fish shell environment.

## QA and Test Design

- For QA, use the `ISO/IEC 25010:2023` quality model as a reference. Select the quality characteristics relevant to the change and its risks, then define verification points and acceptance criteria. Do not apply every quality characteristic uniformly.
- Select appropriate ISTQB test techniques based on the specification, risks, and quality characteristics under test. Techniques include equivalence partitioning, boundary value analysis, decision table testing, state transition testing, statement testing, branch testing, exploratory testing, checklist-based testing, and error guessing.
- In QA plans and PR descriptions, document the selected quality characteristics, test techniques, primary test conditions, and any significant risks left out of scope. Do not apply techniques as a box-checking exercise; be able to explain why each technique was selected and what coverage it is expected to provide.
