# Security Policy

Adopted from the fairyfox hub template — satisfies the OpenSSF Scorecard
**Security-Policy** check. See `notes/reference/adoption-manifest.md`
(supply-chain-hardening row).

## Reporting a vulnerability

Please report security issues **privately** — do not open a public issue for a
suspected vulnerability.

- Use GitHub's **private vulnerability reporting** for this repo:
  **Security → Report a vulnerability** (Settings → Code security → enable
  *Private vulnerability reporting* if it isn't on).
- Or email **junehanabi@gmail.com** with details and, if possible, a reproduction.

You'll get an acknowledgement as soon as it's seen. Please allow a reasonable window
for a fix before any public disclosure.

## Supported versions

`pokered-save-editor-2` is in early alpha. Only the latest released version is
supported; fixes ship in a new release rather than as back-ports.

## Scope

This is a **native desktop application** that runs entirely **client-side**. It reads
and writes Pokémon Red/Blue save files **on the user's own machine** — it has no server,
no accounts, and stores nothing on the maintainer's behalf. Save data never leaves the
device. The only network-facing surface is the project's static documentation site
(GitHub Pages), which collects no personal data.

The project's highest priority is **save-data integrity**: an edit changes only the exact
bits and bytes it must and leaves every other byte untouched. A report of any path that
could corrupt or leak save data is treated with the same seriousness as a code
vulnerability.
