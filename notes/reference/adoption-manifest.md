# Standards adoption manifest

This node's **per-standard record of what is actually adopted** — the artifact whose
absence blocks a summary claim. One row per hub standard. It exists so that no
`Standards adopted ✅` can be written without a backing row, and so a future post-mortem
(or the hub's report-review spot-check) can diff a claim against reality cheaply. Governed
by the hub standards `checklists-are-contracts` and `notes-system` ("The adoption
manifest"); read by the release gate in [`git-workflow.md`](git-workflow.md) → "The
pre-release manifest gate".

> **This node's kind:** a **Qt 6 C++/QML desktop application** (Pokémon Red/Blue save
> editor), open source, with a **Doxygen docs site published to GitHub Pages**. Many
> web-mesh standards (a data-collecting web app, plugin/app-store registries, farm tier)
> genuinely do not apply — those are recorded `N-A(<reason>)`, not silently skipped.

## The rules (do not soften)

- **`copied-only` is not adopted.** A file landing in `notes/reference/` is `copied-only`.
  A row flips to **`implemented`** *only* when that standard's `## Verify` table has been
  run and its result recorded here (date + per-row pass).
- **No summary claim without a row.** `status.md` Health, the registry `adopts_hub` flag,
  and any process report's "adopted X" must be backed by a row in this table.
- **A partial names its remainder.** Every not-yet-adopted standard is a `gap` row with a
  **due** marker — the remainder lives here, owned and dated, never only in prose.

## State vocabulary

`implemented` (Verify run + recorded) · `copied-only` (file present, Verify not run) ·
`gap(<due>)` (not adopted; when it will be) · `N-A(<reason>)` (does not apply to this
project's kind — say why).

## Manifest

`Adopted @` = the hub standards `VERSION` + commit the row was last reconciled against
(this pass: **1.6.0 / 2d614f0**, 2026-07-25). `Last Verify` = date + result (or `—`).

| Standard | State | Adopted @ | Last Verify | Evidence |
|----------|-------|-----------|-------------|----------|
| git-workflow | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | [`git-workflow.md`](git-workflow.md) (git-flow, `--no-ff` tagged releases, manifest gate + full-CI-before-main folded this pass); `CLAUDE.md` Default Workflow §4 |
| versioning | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | [`versioning.md`](versioning.md); repo-root `VERSION` single source → `pse_version.h` |
| notes-system | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | this manifest + evidence-linked `status.md` Health; `notes/_nav.dox` |
| ai-context | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | root `CLAUDE.md` (the AI-context file) |
| cross-project-sync | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | [`cross-project-sync.md`](cross-project-sync.md); this check-for-updates run |
| process-reports | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | [`notes/fairyfox-reports/`](../fairyfox-reports/) (this run's report) |
| compliance | gap(next adopt pass) | 1.6.0 / 2d614f0 | — | no committed `compliance.md` audit file yet; adopted standards carry their own `## Verify`, but the aggregate audit is not filed |
| checklists-are-contracts | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | this manifest (its enforcement artifact) + the not-done disclosure in this run's report |
| mandate-ledger | gap(next multi-part directive) | 1.6.0 / 2d614f0 | — | multi-part owner briefs are currently transcribed into session logs + the task list; a dedicated `notes/plans/*-mandate.md` ledger is not yet used |
| planning | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | phase-by-default is a hard `CLAUDE.md` rule; [`notes/plans/`](../plans/next-steps.md) |
| docs-site | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | Doxygen + vendored shared-chrome bundle **2.3.0**; [`documentation.md`](documentation.md), [`deployment.md`](deployment.md) |
| deployment | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | `.github/workflows/release.yml` + `pages.yml`; [`deployment.md`](deployment.md) |
| testing | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | full `ctest` (92/92); Docker ASan/UBSan/coverage (~90% line); [`plans/testing.md`](../plans/testing.md) |
| engineering-quality | gap(next adopt pass) | 1.6.0 / 2d614f0 | — | ship-contract scorecard (≥7.0 floor) + PR-triage not yet formally tracked; quality bar is enforced in prose (`CLAUDE.md` principles) but not scored |
| ship-contract | gap(next adopt pass) | 1.6.0 / 2d614f0 | — | see engineering-quality; a numeric scorecard artifact is not filed |
| supply-chain-hardening | gap(next adopt pass) | 1.6.0 / 2d614f0 | — | CI runs, but provenance-as-release-asset + SAST-outlives-toolchain-bump not verified this pass |
| dependencies | gap(next adopt pass) | 1.6.0 / 2d614f0 | — | dependabot.yml presence + toolchain↔SAST pin not audited this pass |
| repo-hygiene | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | `.gitignore`/`.gitattributes`; `scripts/check-links.mjs`; git-ignored reference clone |
| docs-lifecycle | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | living notes kept by default (a standing `CLAUDE.md` rule); Doxygen rebuilt on release |
| research-capture | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | "RESEARCH LANDS IN THE NOTES" standing rule; 40+ `reference/*.md` with console probes |
| working-rhythm | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | the by-default build/test/commit loop in `CLAUDE.md` Default Workflow |
| self-hosted-assets | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | self-hosted docs fonts (`docs/fairyfox/fonts/`) — no `fonts.g*` refs; matches chrome 2.3.0 default |
| legal-docs | N-A(no data-collecting web app) | 1.6.0 / 2d614f0 | — | desktop app; the only web surface is the Doxygen Pages docs (no accounts, no PII, no server). Privacy/Terms/Cookies pages do not apply |
| coins | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | `docs/fairyfox/coins.js` shipped via the chrome bundle; reading-engagement counter on the docs site |
| badges | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | `README.md` full badge block (22 badges incl. contributors/stars/CI/docs/release/version/issues/PRs/license) |
| agent-tooling | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | PowerShell-on-Windows workflow; the `pokered-dev` MCP server; `CLAUDE.md` Build System |
| maintenance-sweep | gap(next adopt pass) | 1.6.0 / 2d614f0 | — | no periodic sweep procedure filed; done ad hoc |
| readme | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | worded docs link + "Get it" section + mesh footer added this pass; [`readme` standard `## Verify`](#) |
| docker | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | `docker/` (Dockerfile + `dtest.ps1`) local-first Linux ASan/UBSan/coverage; already-practiced, now filed. `CLAUDE.md` Build System |
| farm-operating-model | N-A(integrated-farm tier only) | 1.6.0 / 2d614f0 | — | single standalone project, not a farm-tier node |
| new-project-setup | N-A(join-time runbook) | 1.6.0 / 2d614f0 | — | procedure, not a standing rule |
| onboarding-existing-project | N-A(join-time runbook) | 1.6.0 / 2d614f0 | — | procedure, not a standing rule |
| adopting-updates | N-A(procedure runbook) | 1.6.0 / 2d614f0 | — | the procedure this manifest is produced by |

## Open gaps (the remainder, owned and dated)

Due **next dedicated adopt/compliance pass** (not this run — each needs real audit work, not
a prose claim):

- **compliance** — file a committed `compliance.md` aggregate audit (run every adopted
  standard's `## Verify`, report done/partial/missing).
- **engineering-quality / ship-contract** — decide whether the numeric Scorecard (≥ 7.0
  floor) applies to this project and, if so, file it; otherwise record a user `N-A`.
- **supply-chain-hardening / dependencies** — audit provenance-as-release-asset, the
  SAST-outlives-toolchain-bump rule, dependabot config, and the toolchain↔SAST pin.
- **mandate-ledger** — adopt the per-clause ledger for the next multi-part owner directive.
- **maintenance-sweep** — file the periodic sweep procedure.
