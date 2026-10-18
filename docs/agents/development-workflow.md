# Agent development workflow

This is the additional workflow for AI-assisted work in this Fork; it supplements, and does not replace, product contexts, ADRs, or CI. Keep the root `AGENTS.md` as the short entry point; load this file for implementation tasks and follow only task-relevant context and ADRs. If explicit project documents conflict, flag the conflict instead of silently choosing a rule.

## 1. Scope and exploration

- Follow the user's requested product area. If unspecified, default to MSDIAL5 (`src/MSDIAL5/`) and read `src/Common/CONTEXT.md` as well.
- Before editing, read `CONTEXT-MAP.md`, the relevant `CONTEXT.md` files, applicable ADRs, the nearest existing tests, and the current CI workflow for the target. For shared code, check relevant call sites; inspect other products only when the change crosses those boundaries.
- Do not read the whole repository or every ADR by default. Search outward from the target code as needed. For nontrivial work, distill the request into observable acceptance criteria and explicit out-of-scope items; do not invent missing scientific or product requirements. Give the user a brief plan when work spans multiple files or has meaningful design choices. Ask only when ambiguity materially affects behavior, data safety, or an irreversible action.
- First inspect `git status`, branch, and existing worktrees. Never overwrite, stash, reset, clean, or delete user changes to make a task easier.

## 2. Naming and code conventions

- Use short kebab-case branch names with a type prefix: `feat/`, `fix/`, `refactor/`, `test/`, or `docs/` (for example, `feat/<short-topic>`).
- Follow the language version, framework, namespace, formatting, and test conventions of the specific project being changed. There is no single style setting for every project in this repository; inspect nearby code and tests rather than imposing a new convention.
- Put tests in the closest relevant test project and use its existing test framework and naming style. Prefer test names that describe observable behavior, not implementation details.

## 3. Branches and worktrees

- A worktree is not required for every task. Use a separate branch and an in-repository `.worktrees/<branch>` worktree for substantial or isolated work: multi-file changes, multiple projects, refactors, or work likely to span sessions. Small, self-contained changes may stay in the current worktree.
- When sessions run concurrently, give each session a unique worktree and branch; never let two sessions edit the same checkout or branch. Check `git worktree list` first and avoid overlapping file ownership. Worktrees isolate files, but do not prevent merge conflicts when tasks touch the same code; coordinate or sequence overlapping work.
- Before creating a worktree, check the selected base and confirm the target branch/path is unused. If the current worktree has uncommitted changes relevant to the task, ask where to continue; never stash, move, reset, or delete them. Do not remove or merge a worktree without the user's direction.
- Do not commit, push, alter remotes, open a PR, or publish artifacts unless explicitly requested. This is especially important because the Fork may be public and laboratory work may be private.

## 4. Risk-based testing

Use testing proportional to behavioral risk, not the number of changed lines:

- Documentation, comments, formatting, and mechanical changes do not require TDD or a new test; run an appropriate lightweight check.
- For a small, low-risk code change, strict red-green is optional. Run the closest existing tests and add a focused regression test when the behavior is not already protected and a suitable test is practical.
- For new behavior, bug fixes with meaningful user impact, and regression-prone algorithm, data-processing, serialization, or export changes, use a vertical red-green loop: add the smallest relevant test, confirm it fails for the expected behavioral reason, implement, then confirm it passes.

Do not change expected results just to make a test pass. For refactors, identify tests that characterize the behavior being preserved. If a UI, vendor SDK, or platform-specific behavior cannot be tested automatically in the available environment, state that limitation and give the appropriate manual verification steps; do not claim it was verified.

## 5. Efficient verification

- During iteration, run the narrowest relevant test project or test filter. For example: `dotnet test <test-project.csproj> --configuration "Debug vendor unsupported" --filter "FullyQualifiedName~<TestName>" --verbosity quiet`. Do not repeatedly run the entire solution after every edit. Before handoff, run the broader checks that are feasible and relevant; use the CI workflow as the source of truth for repository-wide validation.
- Keep successful command output concise. On failure, inspect and report the relevant error details instead of flooding the task context with full build logs.
- Match verification to the change. Prefer the closest existing tests; if the suggested test type is unavailable, state the gap rather than inventing a misleading test.

  | Change | Verification to seek |
  | --- | --- |
  | Behavior, algorithms, or data processing | Focused behavior/regression tests; when analysis or export outputs change, compare a representative approved baseline/reference and explain intentional differences. For deterministic outputs, use a byte/hash diff where practical and normalize only known variable metadata. |
  | Project persistence or serialization | Round-trip and, where applicable, backward-compatibility tests. |
  | API or exported files | Contract, field/header, and compatibility tests. |
  | GUI or platform-specific behavior | Available unit/UI tests plus manual validation on the required platform. |

- Check each project's target framework before choosing a command. The public PR workflow currently runs restore/build/test on Windows with .NET 8 and the `Debug vendor unsupported` configuration. WPF GUI builds and GUI-specific validation require Windows. Targeted .NET 8 test projects can run on macOS; a passing unit-test project is not an end-to-end data or GUI validation. If locked restore fails on macOS due to .NET Framework reference assemblies, do not rewrite lock files as a workaround; use a supported targeted configuration or report the blocker.
- The repository's `Assemblies` directory is a NuGet source used by CI. Do not add vendor SDKs, license files, proprietary binaries, or private raw data to the repository. Confirm format support from the active build and reader implementation rather than assuming a file extension is supported. Private data may be used locally only as permitted; fixtures checked into the repository must be approved for sharing.

## 6. Handoff

Before handoff, review the diff once against the acceptance criteria (spec) and once against repository scope/conventions (standards). Check `git diff --check` and `git status`; do not broaden the change to unrelated cleanup. Update context/ADR/contributor docs only when a durable domain, architecture, public contract, or build/workflow rule changed.

Report briefly:

- what changed and which projects/files were affected;
- exact tests/builds run and their results;
- important checks not run, why, and what platform/data is needed;
- whether any user action is needed.

Do not describe a targeted unit test as a full workflow test. Keep laboratory-specific requirements and data out of public issues, commits, and branches unless the user explicitly confirms they are safe to publish.
