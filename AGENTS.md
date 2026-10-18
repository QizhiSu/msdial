## Agent skills

### Issue tracker

Issues and PRDs for this repo live in GitHub Issues, and external PRs are also a triage surface. See `docs/agents/issue-tracker.md`.

### Triage labels

This repo has no formal triage state machine or canonical label set. Use minimal GitHub labels only when helpful; see `docs/agents/triage-labels.md`.

### Repository development workflow

Before changing source or tests, read `docs/agents/development-workflow.md`. It defines the repository-wide agent workflow; use it together with the relevant context docs and ADRs below. If your AI host does not automatically load `AGENTS.md`, explicitly load it before coding. These instructions guide agents but are not themselves enforcement; automated checks are defined by CI.

Default development targets MSDIAL5, but follow the user's requested product area. Preserve existing work. Do not commit, push, change remotes, or publish artifacts unless the user explicitly asks.

## Domain docs

This repo uses a multi-context layout with `CONTEXT-MAP.md` at the root pointing to per-context `CONTEXT.md` files. Read only the contexts and ADRs relevant to the task. See `docs/agents/domain.md`.
