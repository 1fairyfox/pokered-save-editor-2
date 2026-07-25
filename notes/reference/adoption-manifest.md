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
(this pass: **1.6.1 / 2d614f0**, 2026-07-25). `Last Verify` = date + result (or `—`).

| Standard | State | Adopted @ | Last Verify | Evidence |
|----------|-------|-----------|-------------|----------|
| git-workflow | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | [`git-workflow.md`](git-workflow.md) (git-flow, `--no-ff` tagged releases, manifest gate + full-CI-before-main folded this pass); `CLAUDE.md` Default Workflow §4 |
| versioning | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | [`versioning.md`](versioning.md); repo-root `VERSION` single source → `pse_version.h` |
| notes-system | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | this manifest + evidence-linked `status.md` Health; `notes/_nav.dox` |
| ai-context | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | root `CLAUDE.md` (the AI-context file) |
| cross-project-sync | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | [`cross-project-sync.md`](cross-project-sync.md); this check-for-updates run |
| process-reports | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | [`notes/fairyfox-reports/`](../fairyfox-reports/) (this run's report) |
| compliance | implemented | 1.6.0 / 2d614f0 | 2026-07-25 full pass | [`compliance-audit.md`](compliance-audit.md) — whole-set audit filed (22 done · 5 partial · 5 N-A · 0 missing) |
| checklists-are-contracts | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | this manifest (its enforcement artifact) + the not-done disclosure in this run's report |
| mandate-ledger | implemented | 1.6.1 / 2d614f0 | 2026-07-25 | [`notes/plans/2026-07-25-mandate.md`](../plans/2026-07-25-mandate.md) — this directive transcribed per-clause with status; first instantiation of the ledger |
| planning | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | phase-by-default is a hard `CLAUDE.md` rule; [`notes/plans/`](../plans/next-steps.md) |
| docs-site | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | Doxygen + vendored shared-chrome bundle **2.3.0**; [`documentation.md`](documentation.md), [`deployment.md`](deployment.md) |
| deployment | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | `.github/workflows/release.yml` + `pages.yml`; [`deployment.md`](deployment.md) |
| testing | implemented | 1.6.1 / 2d614f0 | 2026-07-25 (CI green) | Docker ASan/UBSan/coverage (~90% line); **a coverage-floor gate is now wired into the coverage build** (`docker/run-tests.sh` → `COVERAGE_FLOOR`); [`plans/testing.md`](../plans/testing.md). **dev CI is GREEN** (`6ac96ec`: tests + lint + CodeQL all success). The prior red was a pre-existing `tests_all` registration bug (`tst_map_states`/`tst_player` not built by CI) + 3 clang-tidy findings — all now fixed. |
| engineering-quality | implemented | 1.6.1 / 2d614f0 | 2026-07-25 | no-hacks/craftsmanship/doc-comments/source-fidelity enforced in practice + `CLAUDE.md`; the ship-contract Scorecard is now measured objectively by `scorecard.yml` (OpenSSF Scorecard, ≥7.0 target — solo ceiling ~8) |
| ship-contract | implemented | 1.6.1 / 2d614f0 | 2026-07-25 | `scorecard.yml` publishes the OpenSSF score read before ship; the pre-release manifest gate + full-CI-before-`main` enforce the rest |
| ci-secrets | implemented | 1.6.1 / 2d614f0 | 2026-07-25 | Scorecard runs with `GITHUB_TOKEN`+OIDC (no `SCORECARD_TOKEN` needed for a public repo); no Sonar/Codecov wired → those tokens correctly absent (clean, no unknown secret) |
| supply-chain-hardening | implemented | 1.6.1 / 2d614f0 | 2026-07-25 | `SECURITY.md`; least-priv `permissions` on all 4 workflows (top-level read + per-job elevation in `release.yml`); `dependabot.yml`; **all Actions SHA-pinned** (current-major commits); **CodeQL/SAST** (`codeql.yml`); **release provenance** `.intoto.jsonl` asset (`release.yml`); **OpenSSF Scorecard** (`scorecard.yml`); **`main` branch protection SET + verified** (solo config: PR/0-approvals, strict, enforce_admins, no force-push/delete, linear off; required contexts `linux-asan`,`windows`,`static-analysis`,`CodeQL`). Release flow reconciled to PR-based. See [`compliance-audit.md`](compliance-audit.md) |
| dependencies | implemented | 1.6.0 / 2d614f0 | 2026-07-25 audit | `.github/dependabot.yml` (github-actions, grouped, →`dev`); local `ctest` gate; one pinned Qt (6.11 kit==container==CI); app-package ecosystem N-A for CMake/Qt |
| repo-hygiene | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | `.gitignore` + new `.gitattributes` (byte-fidelity binary pins); `scripts/check-links.mjs`; git-ignored reference clone |
| docs-lifecycle | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | living notes kept by default (a standing `CLAUDE.md` rule); Doxygen rebuilt on release |
| research-capture | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | "RESEARCH LANDS IN THE NOTES" standing rule; 40+ `reference/*.md` with console probes |
| working-rhythm | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | the by-default build/test/commit loop in `CLAUDE.md` Default Workflow |
| self-hosted-assets | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | self-hosted docs fonts (`docs/fairyfox/fonts/`) — no `fonts.g*` refs; matches chrome 2.3.0 default |
| legal-docs | N-A(no data-collecting web app) | 1.6.0 / 2d614f0 | — | desktop app; the only web surface is the Doxygen Pages docs (no accounts, no PII, no server). Privacy/Terms/Cookies pages do not apply |
| coins | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | `docs/fairyfox/coins.js` shipped via the chrome bundle; reading-engagement counter on the docs site |
| badges | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | `README.md` full badge block (22 badges incl. contributors/stars/CI/docs/release/version/issues/PRs/license) |
| agent-tooling | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | PowerShell-on-Windows workflow; the `pokered-dev` MCP server; `CLAUDE.md` Build System; root `.gitattributes` now present (CRLF hygiene) |
| maintenance-sweep | implemented | 1.6.1 / 2d614f0 | 2026-07-25 | [`maintenance-sweep.md`](maintenance-sweep.md) — documented audit-first whole-repo tidy composing git-workflow/repo-hygiene/versioning/docs-lifecycle/testing |
| readme | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | worded docs link + "Get it" section + mesh footer added this pass; [`readme` standard `## Verify`](#) |
| docker | implemented | 1.6.0 / 2d614f0 | 2026-07-25 pass | `docker/` (Dockerfile + `dtest.ps1`) local-first Linux ASan/UBSan/coverage; already-practiced, now filed. `CLAUDE.md` Build System |
| farm-operating-model | N-A(integrated-farm tier only) | 1.6.0 / 2d614f0 | — | single standalone project, not a farm-tier node |
| new-project-setup | N-A(join-time runbook) | 1.6.0 / 2d614f0 | — | procedure, not a standing rule |
| onboarding-existing-project | N-A(join-time runbook) | 1.6.0 / 2d614f0 | — | procedure, not a standing rule |
| adopting-updates | N-A(procedure runbook) | 1.6.0 / 2d614f0 | — | the procedure this manifest is produced by |

## Open items (the true remainder)

The 2026-07-25 completion pass closed **every** standing gap — compliance, dependencies,
supply-chain (SHA-pin/CodeQL/provenance/Scorecard/**branch protection**),
engineering-quality/ship-contract, testing (coverage floor gate), mandate-ledger, and
maintenance-sweep are all `implemented`. **Nothing is deferred.**

**Status of the new CI:** all green.

- **dev CI is GREEN** on `6ac96ec`: `tests` (linux-asan + windows), `lint` (static-analysis),
  and `CodeQL` all **success**. The C++ manual-build SAST works; the prior red (a `tests_all`
  registration bug that left `tst_map_states`/`tst_player` unbuilt in CI, plus 3 clang-tidy findings)
  is fixed and verified via the exact CI build path. `scorecard.yml` runs on `main` push + weekly.
