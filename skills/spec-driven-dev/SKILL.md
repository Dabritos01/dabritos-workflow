---
name: spec-driven-dev
description: On-demand spec-driven development workflow using dh/ files for planning, todo generation, and parallel sub-agent execution
---

## Workflow

This is an on-demand workflow. Only use when explicitly loaded.

CRITICAL: Do not advance to the next phase without explicit user approval. Each phase ends with a checkpoint -- wait for the user to confirm before proceeding.

### Phase 1: Spec Intake
- Read the user's rough spec from `dh/<name>.plan.md` at the project root.
- Ask clarifying questions about scope, edge cases, acceptance criteria, and constraints.
- Do not proceed until you understand the full intent.
- **Checkpoint: Wait for user approval to move to Phase 2.**

### Phase 2: Spec Refinement
- Collaborate with the user to refine the spec.
- Update `dh/<name>.plan.md` with the refined version.
- **Checkpoint: Wait for user approval to move to Phase 3.**

### Phase 3: Todo Generation
- Break the refined spec into concrete, actionable tasks.
- Each task should be small enough for a single sub-agent to complete.
- Write the todo list to `dh/<name>.todo.md` and mirror it with TodoWrite for in-session tracking.
- Present the todo list to the user for review.
- **Checkpoint: Wait for user approval to move to Phase 4.**

### Phase 4: Todo Review
- Wait for the user to approve, reorder, or modify the todo list.
- Apply any requested changes to `dh/<name>.todo.md` and TodoWrite.
- **Checkpoint: Wait for user approval to move to Phase 5.**

### Phase 5: Execution
- Use the Task tool to dispatch todo items to sub-agents in parallel where tasks are independent.
- Update both TodoWrite and `dh/<name>.todo.md` as each task completes.
- If a task depends on another, run them sequentially.
- **Checkpoint: Wait for user approval to move to Phase 6.**

### Phase 6: Verification
- Walk through the completed work with the user.
- Run relevant checks (build, lint, tests) as appropriate.
- Confirm the implementation matches the spec in `dh/<name>.plan.md`.

## Conventions
- All spec and todo files live in `dh/` at the project root.
- Spec: `dh/<name>.plan.md`
- Todo: `dh/<name>.todo.md`
- The `dh/` folder is globally gitignored and nothing in it is committed.
