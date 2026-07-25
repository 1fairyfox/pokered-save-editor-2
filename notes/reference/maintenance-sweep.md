# Maintenance sweep — the documented whole-repo tidy

Adopted from the hub **maintenance-sweep** standard: an **audit-first, whole-repo tidy** that
composes the git-workflow, repo-hygiene, versioning, docs-lifecycle, and testing standards into one
periodic pass. It **surfaces** issues for a decision — it does **not** auto-act on anything
destructive. Run it on request, or before a milestone release.

## When to run

- Before a milestone (MINOR/MAJOR) release, or on request ("run a maintenance sweep").
- After a burst of activity that touched many files, or a rename/move.
- Not on a fixed cron — event-based, like the GitHub-prep check.

## The procedure (audit first, act only on go-ahead)

1. **Branch + working-tree state.** `git status` — no stranded/uncommitted files that belong in a
   commit; confirm `dev` contains `main` (`git branch --contains`) and is green (`ctest`). Report
   anything off; never `reset`/`clean` without an explicit request (git-workflow hard rules).
2. **Repo hygiene.** Run the doc-link gate (`scripts/check-links.mjs`); look for stranded files, dead
   internal links, `notes/_nav.dox` subpages missing for any new Markdown (repo-hygiene).
3. **Docs lifecycle.** `status.md` reads as **current-state only** and matches the code; dated history
   (`sessions/`, `version/`) is unedited; removed features are bannered; facts are single-sourced
   (link, don't restate).
4. **Versioning.** `VERSION` is one SemVer line and equals the newest `main` tag; nothing hardcodes a
   version (versioning `## Verify`).
5. **Testing.** Full `ctest` green; the coverage floor gate passes (`docker/dtest.ps1 coverage`); any
   recent fix carries a regression test.
6. **Standards.** Re-run the compliance audit (`compliance-audit.md`) if standards changed since the
   last one; reconcile the [adoption manifest](adoption-manifest.md) rows with reality.
7. **Report, then act only on a go-ahead.** Produce the list of findings; fix the safe hygiene items
   in a focused commit; anything touching history, governance, or a design decision waits for the
   owner's word.

## What a sweep must NOT do

Auto-delete branches without protection confirmation, rewrite history, `reset --hard`, or make a
design/UX change — all forbidden without an explicit request (see `git-workflow.md` hard safety rules
and the project's UI-is-a-design-decision rule). A sweep **surfaces**; the owner decides.
