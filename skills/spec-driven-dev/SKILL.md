---
name: spec-driven-dev
description: Use ONLY when explicitly requested for spec-driven development using dh/ plans, dependency-aware todos, phased approvals, and sub-agent execution
---

## Workflow

This is an on-demand workflow. Only use when explicitly loaded.

CRITICAL: Do not advance to the next phase without explicit user approval. Each phase ends with a checkpoint -- wait for the user to confirm before proceeding.

### Phase 1: Spec Intake
- Read the user's rough spec from `dh/<name>.plan.md` at the project root.
- If the plan name or file is missing:
  - Search only `dh/` for likely context files.
  - Read relevant non-generated context, then ask the user to choose or confirm the spec name.
  - Gather clarification normally, but do not create `dh/<name>.plan.md` in this phase.
- Inspect the repository before asking the user to choose implementation scope. Identify actual call sites, related flows, existing patterns, and existing fallback behavior.
- For redirects, authentication, routing, callbacks, middleware, proxies, or rewrites, trace the complete request path rather than inspecting only its final action. Identify, where relevant, what selects the page, restores state, validates or transforms input, and sends the response.
- Ask only focused questions that remain unresolved by the rough spec and repository evidence. Cover applicable gaps in scope, security or behavioral boundaries, edge cases, fallback behavior, acceptance criteria, constraints, and exclusions.
- If the user answers a scope question with another question, pause the checkpoint. Investigate it, answer with concrete files and behavior, then ask for the scope decision again.
- Summarize the discovered behavior and unresolved decisions. Do not proceed until the full intent is understood.
- **Checkpoint: Explicitly ask for approval to move to Phase 2, then wait.**

### Phase 2: Spec Refinement
- Collaborate with the user to refine the spec.
- Only after Phase 2 is approved, create or update `dh/<name>.plan.md` with the refined version.
- Include applicable detail proportionate to the change:
  - Problem and impact, goal, in-scope locations or flows, and explicit exclusions.
  - Exact validation or behavior rules, including the trust boundary for security work. Do not use vague requirements such as "sanitize input."
  - Accepted and rejected examples, or success and failure examples, when they clarify behavior.
  - Invalid-input or failure behavior and existing behavior that must be preserved.
  - Testable acceptance criteria.
- Distinguish stages in a request path when their separate behavior could affect implementation or manual testing.
- Summarize what the refined plan formalizes.
- **Checkpoint: Explicitly ask for approval to move to Phase 3, then wait.**

### Phase 3: Todo Generation
- Break the refined spec into concrete, actionable tasks.
- Each task must include:
  - A concrete outcome.
  - Relevant file or subsystem ownership when known.
  - The verification expected from that task.
  - A `Depends on` line, including `Depends on: none` for root tasks.
  - Whether, and with which tasks, it can run in parallel.
- Make each task small enough for one sub-agent, but do not split tightly coupled edits solely to create parallel work.
- Encode shared prerequisites before dependents and prefer non-overlapping file ownership for tasks that may run concurrently.
- Write the todo list to `dh/<name>.todo.md` and mirror it with TodoWrite for in-session tracking.
- Present the dependency-aware todo list to the user for review.
- **Checkpoint: Explicitly ask for approval to enter Phase 4, then wait.**

### Phase 4: Todo Review
- Wait for the user to approve, reorder, or modify the todo list.
- Apply any requested changes to `dh/<name>.todo.md` and TodoWrite.
- Do not begin implementation in this phase.
- **Checkpoint: Explicitly ask for approval to move to Phase 5, then wait.**

### Phase 5: Execution
- Complete shared prerequisites before dispatching their dependents. Dispatch tasks in parallel only when they are independent, and prefer non-overlapping file ownership.
- Give every sub-agent:
  - The exact task and acceptance criteria.
  - Its allowed files or subsystem and files it must not modify.
  - Required checks and whether it should update `dh/<name>.todo.md`. Prefer parent-owned updates when concurrent agents would share that file.
  - A prohibition on committing unless the user requested a commit.
  - This exact instruction: "The user has approved Phase 5 execution. This authorizes the edits in this task. Do not pause for another plan or approval checkpoint."
- After each agent finishes, inspect its actual diff and checks rather than relying only on its summary. Confirm it respected task boundaries.
- Update TodoWrite and `dh/<name>.todo.md` in real time as each task completes. Run dependent tasks only after their prerequisites have been inspected and completed.
- **Checkpoint: Explicitly ask for approval to move to Phase 6, then wait.**

### Phase 6: Verification
- Independently verify the integrated work even when sub-agents report successful checks.
- Run the normal relevant build, lint, test, formatting, and type-check commands as appropriate, then confirm the implementation against each acceptance criterion in `dh/<name>.plan.md`.
- If a normal project check cannot run:
  1. Run it and retain the actual failure.
  2. Determine whether the failure was caused by the change or by missing or pre-existing artifacts.
  3. Run meaningful focused tests, lint, formatting, type checks, and diff checks.
  4. Search for missed call sites and unsafe old patterns.
  5. State exactly which full check remains unavailable. Never report a blocked check as passing.
- Walk through the completed behavior with the user and report passes, failures, warnings, and environmental gaps separately.

## Collaboration

- Keep checkpoint messages and progress updates concise. Send an update only for a significant discovery, decision or tradeoff, blocker, or the start of substantial edits or verification. Do not narrate routine reads, searches, or successful minor commands.
- If manual testing produces surprising behavior, investigate and explain it with concrete code references in this order:
  1. What selected the route or page.
  2. What validated or transformed the input.
  3. Why the observed fallback occurred.
  4. Whether the acceptance criterion still holds.
- Distinguish successful security enforcement from unrelated routing or rendering behavior.

## Conventions
- All spec and todo files live in `dh/` at the project root.
- Spec: `dh/<name>.plan.md`
- Todo: `dh/<name>.todo.md`
- The `dh/` folder is globally gitignored and nothing in it is committed.
