---
date: 2026-07-25
procedure: adopting-updates
node: pokered-save-editor-2
outcome: completed
hub_version: 1.6.1
hub_commit: 2d614f0
chrome_version: 2.3.0
---

# Process Report — adopting-updates, 2026-07-25

> A full, honest account of running a fairyfox system procedure. The point is to improve the system —
> so say what was rough even if the run succeeded. Voice: direct, matter-of-fact, no hype.
> Standard: `hub/standards/process-reports.md`.

## Outcome in one line

Adopted the hub standards batch **1.6.1** (standards 1.4.0→1.6.0) + shared-chrome **2.3.0** into this
desktop-app node: created the keystone **adoption manifest**, added the new **readme** cross-links and
filed the already-practiced **docker** standard, folded the **git-workflow** (pre-release manifest gate
+ full-CI-before-`main`) and **notes-system** (evidence-linked status) deltas, and pinned chrome to
2.3.0 (self-hosted fonts — the node's former deviation is now the mesh default). Docs/notes-only; no
app code touched. Committed to `dev`. Owed items recorded as dated `gap` rows, not left in prose.

## What was done

1. **Refreshed** the read-only hub mirror at `assets/references/fairyfox.io/`. `dev` had been
   force-pushed (routine), so `--ff-only` aborted and the `reset --hard origin/dev` fallback ran on the
   git-ignored mirror — `697bc5c → 2d614f0`, hub VERSION **1.6.1** (was 0.20.2 at the last adoption).
2. **Read the express-authorization ledger** (`hub/authorizations.yml`). The standing
   `adopt-standards-by-default` entry (2026-07-02, no expiry) covers `hub/standards/` + `hub/templates/`,
   so the whole standards/template delta is **pre-authorized**: applied without the check-report-wait
   pause. Every other safety step still ran (copy-not-clobber, divergence re-prompt, full verification,
   this report, a reviewable commit). The owner also expressly said "proceed … to completion."
3. **Diffed** `697bc5c → 2d614f0` against this node's last-adopted anchor (chrome 2.2.1 @ 697bc5c, per
   the `2026-07-19-adopting-updates-chrome-2.2.1.md` report). Used the standards `CHANGELOG.md` (new
   1.4.0/1.5.0/1.6.0 entries) + the chrome `CHANGELOG.md` (2.3.0) to tell *new* from *materially-changed*
   without a full-tree object diff. Classified each standard by applicability to a **Qt C++/QML desktop
   app with a Doxygen Pages docs site**.
4. **Created `notes/reference/adoption-manifest.md`** (the new keystone artifact from
   `notes-skeleton/reference/adoption-manifest.md`) — one row per hub standard, honest state, this pass's
   Verify results, evidence links. Wired its `\subpage` into `notes/_nav.dox`. Web-mesh-only standards
   (`legal-docs`, `farm-operating-model`, join-time runbooks) are recorded `N-A(<reason>)`, not skipped.
5. **readme standard (1.6.0):** added a worded docs link near the top, an organized **"Get it"**
   section (releases/download · docs · source; honest note that no live-app/registry rows apply to a
   desktop app), a TOC entry, and a **mesh footer** linking fairyfox.io — reconciled into the existing
   README, its content and voice unchanged.
6. **docker standard (1.5.0):** already practiced (`docker/` Dockerfile + `dtest.ps1`, local-first
   Linux ASan/UBSan/coverage). Filed as `implemented` in the manifest — "already-practiced, now-filed".
7. **git-workflow (1.6.0):** added the **pre-release manifest gate** and **full-CI-before-`main`
   (platform-enforced)** sections to the committed `notes/reference/git-workflow.md`.
8. **notes-system (1.6.0):** the adoption manifest + an **evidence-linked** dated entry at the top of
   `status.md` (links the manifest + this report), satisfying the "no bare ✅" rule.
9. **Chrome 2.2.1 → 2.3.0:** verified the node already self-hosts the three OFL subsets with **zero**
   `googleapis`/`gstatic` refs, so 2.3.0 (self-hosted fonts) is a no-op beyond pinning
   `docs/fairyfox/CHROME_VERSION → 2.3.0`. The per-node font deviation carried since 2026-07-19 is
   retired — it is now the standard.
10. **Verified + committed** only the six fairyfox files to `dev`, leaving the concurrent map-screen
    WIP in the working tree untouched.

## What went well

- The **standards `CHANGELOG.md` + chrome `CHANGELOG.md`** made "what's new since my anchor" a clean
  read instead of a guess — exactly what they were added for. The 2026-07-19 report had asked for a
  chrome changelog; it now exists and was used.
- The **authorization ledger's standing grant** made the apply decision unambiguous.
- The node was **already at the 2.3.0 font posture** (its documented deviation), so the chrome bump
  landed for free and closed the deviation the previous two reports had flagged/recommended.
- The **adoption manifest template** was well-shaped; filling it honestly for a non-web node was
  straightforward once the `N-A(<reason>)` vocabulary was applied.

## What went wrong / friction

- **Site version vs standards version is still two numbers.** Prior reports anchored on the hub *site*
  version (0.16.1, 0.20.2); the standards `CHANGELOG` is versioned 1.4.0/1.5.0/1.6.0; the hub root
  `VERSION` is now **1.6.1**. They appear to have converged, but a reader can't be sure the standards
  version and the site version are the same series. Recorded `hub_version: 1.6.1` (root VERSION) as the
  durable anchor, but a one-line "the standards version == the hub VERSION" note in the CHANGELOG header
  would remove the doubt.
- **Concurrent working-tree WIP.** The repo had unrelated, uncommitted map-screen code changes on
  arrival (mapmodel/MapCanvas/new pickers). Correct handling is to stage only the adoption files — but
  it means the normal "run the full suite to verify" floor can't run meaningfully (it would build
  someone else's half-done work, not my change). For a **docs/notes-only adoption** the honest floor is
  "no code touched → suite unaffected", which is what I recorded. A line in `adopting-updates.md` for
  the docs-only case ("when the adoption touches no build inputs, the verification floor is scope-proof
  + link/render checks, not a full rebuild") would make this explicit rather than a judgment call.
- **Several 1.4.0 standards want audit work, not a prose tick** (compliance audit file, ship-contract
  scorecard, supply-chain provenance/SAST, dependencies). Marking them `implemented` in one pass would
  be exactly the drift `checklists-are-contracts` warns about, so they are dated `gap` rows for a
  dedicated pass. That's the standard working as intended, but it means "adopt the batch in full" is
  genuinely two passes for a node this size.

## Suggestions / feedback

- **CHANGELOG header:** state that the standards-set version tracks the hub root `VERSION` (or give the
  standards their own explicit version line), so an adopter isn't reconciling two numbering schemes.
- **`adopting-updates.md`:** add a short "docs-only adoption" note — when the change touches no build
  inputs, the verification floor is scope-confirmation (only non-build files changed) + link/render
  checks, not a full rebuild. This is the common shape for standards/README/notes adoptions.
- **Manifest template:** consider shipping a tiny `N-A` legend for common node *kinds* (desktop app,
  library, static site) so each node doesn't re-derive which web-mesh standards don't apply.

## Follow-up (same day) — compliance audit + safe supply-chain measures

On the owner's "finish it in full" follow-up, ran a second pass to work the manifest `gap` rows down
rather than leave them purely dated:

- **Filed `notes/reference/compliance-audit.md`** — the whole-set audit (every standard's `## Verify`
  for this node): **22 done · 5 partial · 5 N-A · 0 missing**, each gap named. The `compliance` and
  `dependencies` manifest rows flip to `implemented`.
- **Adopted the self-contained supply-chain measures** (no release-pipeline blast radius): root
  `SECURITY.md`; least-privilege `permissions: contents: read` on `lint.yml` + `tests.yml` (the two
  that lacked it); `.github/dependabot.yml` (github-actions ecosystem → `dev`; the app-package
  ecosystems don't apply to CMake/Qt). Added root `.gitattributes` with **explicit `binary` pins for
  the 226 `.blk` / 14 `.sav` / 4 `.bin` fixtures** — a byte-fidelity safeguard this project's values
  demand and the bare hub template didn't cover.
- **Deliberately deferred** the measures that touch the **live release pipeline** or **repo
  governance** — SHA-pinning Actions (needs verified SHAs; dependabot will then maintain), a CodeQL/SAST
  workflow (a C++ CodeQL build against Qt/llvm-mingw is real integration work, not a blind drop),
  release provenance-as-asset in `release.yml` (untestable from here; only runs on `main`), and `main`
  branch protection + required-status-check contexts (`gh api`; governance is the owner's call). These
  are `partial`/`gap` rows with recipes, for a dedicated CI/security pass.

**Judgment call, stated:** "adopt in full" for a node this size is genuinely two kinds of work — the
safe repo-config/doc adoptions (done) and a briefed CI/security effort (deferred). Marking the latter
`implemented` in a docs pass would be exactly the drift `checklists-are-contracts` exists to stop, so
they stay honest `partial` rows. This pass touched **no app code** — only docs/notes and safe
repo-config; the two workflow `permissions` blocks are validated by the next `dev` CI run.

## Environment

- **Node:** `pokered-save-editor-2` — Qt 6.11 C++/QML **desktop** app (llvm-mingw kit), open source,
  Doxygen docs published to GitHub Pages via `pages.yml`, releases via `release.yml`. Git-flow (`dev` →
  `--no-ff` tagged `main`); **releases are manual** (ship on the owner's word).
- **OS/shell:** Windows, PowerShell (the repo's mandated shell; the Cowork bash sandbox is not used here
  due to stale-mount reads).
- **On arrival:** clean adopted history plus **unrelated uncommitted map-screen WIP** in the working
  tree — staged around it. Last adoption 2026-07-19 (chrome 2.2.1). Branch: `dev`.
