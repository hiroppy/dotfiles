---
name: simplify
description: Simplify recently written or modified code while preserving behavior. Use this skill whenever the user asks to simplify, clean up, reduce complexity, remove over-engineering, make code easier to read, or run a simplify pass after implementation or bug fixing.
---

# Simplify

Refine code for clarity, consistency, and maintainability without changing what it does. Prefer boring, explicit code that fits the project over clever or compact rewrites.

## Scope

- Default to code changed in the current task, current branch, or explicitly requested files.
- If the target is unclear, inspect the working tree diff first and focus on changed files.
- Do not perform broad refactors unless the user explicitly asks for a wider cleanup.
- Preserve public APIs, data formats, side effects, error behavior, and user-visible output unless the user requested a behavior change.

## Workflow

1. Understand the current behavior from code, tests, usage sites, and the user's request.
2. Identify simplification opportunities:
   - unnecessary abstraction or indirection
   - duplicated logic
   - avoidable nesting or branching
   - overly generic helpers used only once
   - unclear names or control flow
   - comments that merely restate obvious code
   - inconsistent style compared with nearby code
3. Apply small, reviewable edits that make the code easier to reason about.
4. Prefer existing project conventions and utilities over introducing new patterns.
5. Run the most relevant available checks: tests, typecheck, lint, format, or a focused command. If checks cannot be run, explain why.
6. Report what changed, what behavior was preserved, and what verification was performed.

## Simplification principles

- Clarity beats fewer lines. Do not collapse logic into dense one-liners just to make code shorter.
- Avoid nested ternaries for multi-branch logic; use `if`/`else`, early returns, lookup tables, or `switch`/pattern matching when clearer.
- Prefer local reasoning. Keep related logic close together unless extraction clearly improves readability or reuse.
- Remove abstractions that hide simple behavior, but keep abstractions that encode real domain concepts or are used consistently across the project.
- Choose names that explain intent rather than mechanics.
- Keep error handling explicit enough that failure modes remain understandable.
- Avoid mixing unrelated concerns in the same function while simplifying.

## Safety checks

Before finalizing, confirm:

- No intentional behavior changed.
- Existing tests still pass, or the reason they were not run is documented.
- The diff is smaller or easier to review than the original approach.
- New helpers, if any, have at least a clear reason to exist.
- The style matches nearby code and repository guidance files when present.

## Response format

When done, summarize briefly:

- **Simplified:** key cleanup points
- **Preserved:** behavior/API assumptions kept unchanged
- **Verified:** commands run and results, or why verification was skipped
