---
name: start-ticket
description: Checks whether a GitHub issue is ready and proposes a plan before any work begins. Use when the user wants to begin a ticket, e.g. "start #12" or "zacznij #12". Not for questions about a ticket, such as "what is #12 about?".
---

# Start a ticket

Read-only until the owner approves the plan: no file changes, branches,
comments or board changes. Do not run project scripts, not even in a check mode.

One command per call, from the repository root: no `&&`, `;`, loops or `cd`.
One part that needs permission blocks the whole chain, and `cd` persists, so
`gh` and `git` may end up in another repository.

## 1. Read

- `gh issue view N --json number,title,body,state,labels,comments,projectItems`
  (`--comments` prints nothing when there are no comments)
- The same for every issue it depends on. Judge by issue state, not the board.
- `git fetch`, then `git status -sb`

## 2. Check

Report each result, also when it is fine:

- every item of the [Definition of Ready](../../../CONTRIBUTING.md#definition-of-ready)
- dependencies are closed
- on `main`, clean, level with `origin/main`

If the issue is closed, not ready or blocked, **stop here**: say what is missing
and what to do first (for an L ticket, propose a split). No plan, no research,
unless the user asks for a plan anyway; then mark what it assumes.

If only the working tree is the problem, say so and continue.

## 3. Plan

- files to create or change
- how each acceptance criterion will be verified
- out of scope
- questions, each with a recommendation

Wait for approval. It covers the plan only; ask separately before anything
the repository rules require asking for.

Reply in the language the user writes in.
