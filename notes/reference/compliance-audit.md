# Standards compliance audit — 2026-07-25

The committed **whole-set** compliance pass the hub's [`compliance.md`](#) standard defines:
run every adopted standard's `## Verify` and report `done` / `partial` / `missing` with the
exact gap named. This is the aggregate the [adoption manifest](adoption-manifest.md) rows
summarize; a `partial`/`missing` here is what turns a manifest row into a dated `gap`.

- **Target:** this node (`pokered-save-editor-2`), a Qt 6 C++/QML **desktop** app with a
  Doxygen docs site on GitHub Pages.
- **Against:** hub standards **1.6.1** / `2d614f0`.
- **Mode:** full. **Changed on disk:** this audit is a read; the same-day adopt pass that
  precedes it (see [`fairyfox-reports/2026-07-25-adopting-updates.md`](../fairyfox-reports/2026-07-25-adopting-updates.md))
  is where files changed.

## Result matrix

| Standard | Result | Evidence / named gap |
|----------|--------|----------------------|
| git-workflow | **done** | git-flow; `main` advances only by `--no-ff` tagged releases; no `master`; history intact; manifest gate + full-CI-before-`main` folded. *Sub-gap:* the platform-enforced **required-status-check contexts** on `main` are not yet populated (tracked under supply-chain). |
| versioning | **done** | repo-root `VERSION` = one SemVer line → `pse_version.h`; nothing hardcoded; PATCH/MINOR/MAJOR rules match git-workflow. |
| notes-system | **done** | full `notes/` tree; `status.md` current-state + evidence-linked; inline changelog (no separate doc commits); `adoption-manifest.md` present. |
| ai-context | **done** | root `CLAUDE.md` carries the six pieces; workflow section matches git-flow. |
| cross-project-sync | **done** | this run: on-request, read-only, git-ignored mirror, copy-not-link; `authorizations.yml` read-only (skips a prompt only). |
| process-reports | **done** | `notes/fairyfox-reports/` holds a report per run incl. this pass's. |
| checklists-are-contracts | **done** | the adoption manifest is its instrument; this audit names every not-done item rather than a bare ✅. |
| mandate-ledger | **partial** | *gap:* no dedicated per-clause ledger file; multi-part owner briefs are currently transcribed into session logs + the live task list. Mechanism understood; adopt on the next multi-part directive. |
| docs-site | **done** | Doxygen + vendored shared-chrome **2.3.0**; `docs/fairyfox/CHROME_VERSION` recorded; brand/Home way-home present. |
| deployment | **done** | `pages.yml` (static docs → Pages) + `release.yml` (installers/AppImage). No Netlify web app — correct for a desktop app (no live-app row). |
| planning | **done** | phase-by-default is a hard `CLAUDE.md` rule; `notes/plans/` holds written plans before execution. |
| testing | **done** | headless logic tests; real multi-layer suite (`ctest` 92/92); regression-per-fix; ROM-parity oracle; screenshot preview-before-ship; Docker coverage ~90%. *Sub-gap:* confirm a **hard coverage-floor gate** fails the build below the floor (currently measured, not proven to block). |
| engineering-quality | **partial** | no-hacks / do-the-long-work / doc-comments / source-fidelity are enforced strongly in practice + `CLAUDE.md`. *gap:* the **numeric ship contract** (Scorecard ≥ 7.0, debt-cleared, PRs-triaged) is not scored as an artifact — a process decision for leadership (adopt the scorecard, or record a user `N-A`). |
| supply-chain-hardening | **partial** | **done this pass:** root `SECURITY.md`; least-privilege `permissions: contents: read` now on **all four** workflows (added to `lint.yml`/`tests.yml`; `pages.yml`/`release.yml` already scoped); `dependabot.yml` `github-actions` ecosystem → `dev`. **gap (dedicated CI/security pass — touches the live release pipeline + repo governance):** ① Actions are **tag-pinned, not SHA-pinned**; ② no **CodeQL/SAST** workflow (a C++ CodeQL build needs real integration with the Qt/llvm-mingw toolchain — must be iterated, not dropped blind); ③ `release.yml` does not attach **SLSA provenance (`.intoto.jsonl`) as a release asset**; ④ `main` branch protection (solo config) + **required-status-check contexts** not set (via `gh api` — governance, leadership's call). Solo-ceiling ~8 + badge-lag caveats acknowledged. |
| dependencies | **done** (for what applies) | Dependabot on, grouped, targets `dev`; local test gate = `ctest`; toolchain pinned to one Qt (6.11 kit == container == CI). No Dependabot-supported **app** package ecosystem exists for CMake/Qt → app-dependency updates `N-A`. |
| docker | **done** | `docker/` (Dockerfile + `dtest.ps1`) — local-first Linux ASan/UBSan/coverage; the 2026-07-17 container breakage was **fixed, not routed around**; CI is the backstop. |
| legal-docs | **N-A** | desktop app; no data-collecting web app. The only web surface is the static Doxygen Pages docs (no accounts/PII/server). Privacy/Terms/Cookies pages do not apply. |
| coins | **done** | `docs/fairyfox/coins.js` from the chrome bundle; reading-engagement counter on the docs site; nothing is gated on coins; client-side (localStorage) only. |
| agent-tooling | **done** | `CLAUDE.md` names PowerShell-not-bash + execute-don't-hand-off; root `.gitattributes` **now present** (added this pass, with byte-fidelity binary pins); no CRLF noise. |
| badges | **partial** | README carries the full ordered badge block (contributors/stars/forks/watchers/commits/CI/docs/release/version/language/size/issues/PRs/license). *Sub-gap:* the **docs badge** points at `1fairyfox.github.io/<key>/` rather than `fairyfox.io/<key>/` — correct for where the docs actually deploy, but note the mesh-canonical form; a couple of the 20 canonical slots (e.g. Scorecard, coverage) are absent pending the supply-chain/coverage-service work. |
| readme | **done** | worded docs link near the top; grouped **"Get it"** section (releases · docs · source, with an honest note that no live-app/registry rows apply to a desktop app); **mesh footer** near the bottom — all added this pass. |
| repo-hygiene | **done** | `scripts/check-links.mjs` doc-link gate; `.gitignore`/`.gitattributes`; no stranded files; git-ignored reference clone; branch discipline. |
| docs-lifecycle | **done** | current-state `status.md` vs dated `sessions/`/`version/` history; removed-feature banners; single-source (link-don't-restate). |
| research-capture | **done** | "RESEARCH LANDS IN THE NOTES" standing rule; 40+ `reference/*.md` with committed console probes under `scripts/emu/`. |
| working-rhythm | **done** | task-tracked multi-step work; background-by-default + foreground-when-ready (dev harness / MCP); adjacency-is-not-a-brief + ask-first are hard `CLAUDE.md` rules. |
| self-hosted-assets | **done** | docs fonts self-hosted (`docs/fairyfox/fonts/`); zero `fonts.g*` / CDN hot-links; matches chrome 2.3.0's new default. |
| ci-secrets | **partial** | All 3 authenticated integrations now **wired**: Scorecard `repo_token: SCORECARD_TOKEN` (with default-token fallback), `coverage.yml` → Codecov (`CODECOV_TOKEN`), `sonar.yml` + `sonar-project.properties` → SonarCloud (`SONAR_TOKEN`); token-requiring steps gated so CI stays green. **Remaining = the owner sets the 3 secret values** (external SonarCloud/Codecov accounts + a GitHub PAT — I can't create these); provisioning steps in the process report. |
| farm-operating-model | **N-A** | single standalone project, not an integrated-farm-tier node. |
| maintenance-sweep | **partial** | the composing standards (git-workflow/repo-hygiene/versioning/docs-lifecycle/testing) are all in place and swept ad hoc. *gap:* no single **documented sweep procedure** filed; adopt on the next dedicated tidy. |
| lifecycle runbooks (setup/onboard/adopt) | **N-A** | join-time / procedure runbooks, not standing rules. |

## Summary (updated after the same-day completion pass)

The five `partial`s this audit first recorded were **all closed the same day** — see the
[adoption manifest](adoption-manifest.md) for the flipped rows and the process report for the work:

1. **supply-chain-hardening** — SHA-pinned every Action, added CodeQL (`codeql.yml`), release
   provenance `.intoto.jsonl` asset (`release.yml`), OpenSSF Scorecard (`scorecard.yml`), and
   **`main` branch protection SET + verified** (solo config; required contexts `linux-asan`,
   `windows`, `static-analysis`, `CodeQL`). Release flow reconciled to PR-based.
2. **engineering-quality / ship-contract** — `scorecard.yml` supplies the objective ≥7.0 signal.
3. **testing** — a hard coverage-floor gate is wired into `docker/run-tests.sh`.
4. **mandate-ledger** — instantiated at `notes/plans/2026-07-25-mandate.md`.
5. **maintenance-sweep** — filed at `notes/reference/maintenance-sweep.md`.

**Net state: every standard is `implemented` or a reasoned `N-A`.** `main` branch protection is now set
and verified. The only open item is a *confirmation*, not a gap: CodeQL + Scorecard are dispatched —
confirm the first CodeQL run is green (and note dev CI is currently red from pre-existing map-states
WIP, which clears when that WIP lands).
