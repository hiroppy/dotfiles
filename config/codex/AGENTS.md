# Global Codex Instructions

## Pull Requests

- Write pull request titles that follow Conventional Commits.
- If the repository contains a pull request template, use it as the basis for the pull request description.

## QA and Test Design

- For QA, use the `ISO/IEC 25010:2023` quality model as a reference. Select the quality characteristics relevant to the change and its risks, then define verification points and acceptance criteria. Do not apply every quality characteristic uniformly.
- Select appropriate ISTQB test techniques based on the specification, risks, and quality characteristics under test. Techniques include equivalence partitioning, boundary value analysis, decision table testing, state transition testing, statement testing, branch testing, exploratory testing, checklist-based testing, and error guessing.
- In QA plans and PR descriptions, document the selected quality characteristics, test techniques, primary test conditions, and any significant risks left out of scope. Do not apply techniques as a box-checking exercise; be able to explain why each technique was selected and what coverage it is expected to provide.
- When creating a pull request, include screenshots or short screen recordings when they materially help reviewers verify user-visible changes, interaction flows, responsive behavior, animations, or platform-specific behavior in web or mobile applications. Use screenshots for static visual states and recordings for interactions or state transitions. Omit them when there is no meaningful visual or behavioral impact or when the required capture environment is unavailable; no explanation for their absence is required.
- Before attaching visual evidence, remove or obscure sensitive, personal, customer, authentication, and environment-specific information.
