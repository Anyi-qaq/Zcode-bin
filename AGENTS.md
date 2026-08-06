# Repository Guidelines

## Project Overview

AUR packaging repository for `zcode-bin`: repackages [ZCode](https://zcode.z.ai/) (proprietary AI-powered code editor by ZAI) for Arch Linux. Upstream ships a Linux `.deb`; this repo's `PKGBUILD` extracts the app resources and launches them via system `electron41` instead of bundling Electron (~250MB saved). The repo contains **no application source code** — its only product is the packaging that keeps the AUR package current. A daily GitHub Actions cron auto-detects upstream releases, updates `PKGBUILD`/`.SRCINFO`, validates, and pushes to GitHub + AUR.

## Architecture & Data Flow

Single upstream source, one pipeline:

```
cdn-zcode.z.ai .deb ──► zcode-update-checker.sh ──► PKGBUILD (+.SRCINFO) ──► CI ──► GitHub repo + AUR + Release
```

- **Update pipeline** (`.github/workflows/update-aur.yml`, daily cron `0 0 * * *` + manual `workflow_dispatch`): runs `./zcode-update-checker.sh --update` → syncs `.SRCINFO` from PKGBUILD via sed → validates (`bash -n`, namcap in `archlinux:latest` docker) → commits `chore: update to ZCode <ver>` → pushes to GitHub (`main`) and AUR (`master`), creates a `v<ver>` GitHub Release. Needs `AUR_SSH_KEY` secret and `permissions: contents: write`.
- **Update checker** (`zcode-update-checker.sh`): scrapes the ZCode changelog for the latest version (CDN probing as fallback), verifies/downloads the `.deb`, pins its SHA-256, and `sed -i`-rewrites `pkgver`/`pkgrel`/`source`/`sha256sums` in `PKGBUILD`.
- **Build flow** (makepkg): `bsdtar`-extracts `data.*` from the `.deb` → `prepare()` patches the launcher (sed token substitution), strips the `/opt/ZCode/` prefix from the `.desktop` `Exec` line, unpacks/patches/repacks `app.asar` (redirects `process.resourcesPath` to `/usr/lib/zcode`), symlinks system `ripgrep` over the bundled one, trims arch-specific bloat → `package()` installs to `/usr/bin/zcode-bin`, `/usr/lib/zcode-bin/`, `/usr/share/applications/`, `/usr/share/icons/hicolor/*/`, `/usr/share/licenses/zcode/`.
- **Runtime**: `/usr/bin/zcode` launcher `exec`s `electron41 <app.asar>` with Chromium memory-reclamation flags, user flags, and sandbox args. No `.install` hook — pacman hooks from `desktop-file-utils`/`gtk3`/`shared-mime-info` handle post-install integration.

## Key Directories

The repo is flat — root files ARE the source tree. Only subdirectory:

- `.github/workflows/` — the single CI workflow (`update-aur.yml`).

## Development Commands

```bash
makepkg -si                        # build and install
makepkg                            # build only
makepkg --printsrcinfo >| .SRCINFO # regenerate AUR metadata (use >| not > — zsh noclobber)
namcap PKGBUILD                    # lint PKGBUILD
namcap zcode-bin-*.pkg.tar.zst     # lint built package
./zcode-update-checker.sh          # dry run: check for upstream update
./zcode-update-checker.sh --update # check and update PKGBUILD in place
```

## Code Conventions & Common Patterns

- **Shell style**: bash, `snake_case` variables, 4-space indent, `echo`-based output. `zcode.sh` uses `set -e`; `zcode-update-checker.sh` uses `set -euo pipefail` plus `log_info`/`log_warn`/`log_error` helpers — follow the stricter latter pattern in new scripts.
- **PKGBUILD conventions**: bash arrays; `_pkgname`-style private vars (`_pkgname=ZCode`, `_electronversion=41`); version-pinned renamed source: `zcode-<ver>-x86_64.deb::https://cdn-zcode.z.ai/zcode/electron/releases/<ver>/linux-x64/ZCode-<ver>-linux-x64.deb`; git-tracked local files (`LICENSE`, `zcode.sh`) appear as `SKIP` sha256sums entries; `options=('!strip')`.
- **Launcher template tokens**: `zcode.sh` carries build-time placeholders (`@appname@`, `@runname@`, `@cfgdirname@`, `@electronversion@`) substituted by `sed` in `prepare()`. Keep them in sync with the PKGBUILD sed commands; never hardcode values the build must substitute.
- **Electron launcher invariants** (`zcode.sh`): `"${_RUNNAME}"` must stay argv[1] right after the electron binary — ZCode uses `process.argv[1]` as its deep-link entry; all switches go after it. Memory-flag defaults are placed **before** user flags so flags.conf values win (last one wins). Flag sources load in order: `$XDG_CONFIG_HOME/electron-flags.conf` → `electron<ver>-flags.conf` → `<app>-flags.conf` → `<cfgdir>/<app>-flags.conf`. `ZCODE_MEMORY_SAVER=1` adds `--disable-gpu` + `--js-flags=--max-old-space-size=3072`.
- **HTTP checks**: `url_exists()` must use `curl -w '%{http_code}'` with `-L` — old `grep '200 OK'` fails on HTTP/2.
- **`.SRCINFO`**: tabs must be real tab characters; CI emits them via `printf '\t'` in sed, never `\\t`.
- **Commit convention**: `chore: update to ZCode <ver>`.
- **Version bumps**: after changing `pkgver`, regenerate `.SRCINFO` (`makepkg --printsrcinfo >| .SRCINFO`). If the launcher reports an Electron version mismatch, update `_electronversion` in `PKGBUILD`.

## Important Files

- `PKGBUILD` — the only file that matters for building: source URL, sha256, `prepare()`/`package()` steps.
- `.SRCINFO` — AUR metadata; always regenerate, never hand-edit tabs.
- `zcode.sh` — launcher script template (installed to `/usr/bin/zcode`).
- `zcode-update-checker.sh` — version checker/updater, driven by CI (`--update`, `--help`).
- `.github/workflows/update-aur.yml` — cron update + validation + AUR/GitHub push pipeline.
- `README.md` / `CLAUDE.md` — usage docs; keep in sync when behavior (flags, layout) changes.

## Runtime/Tooling Preferences

- **Runtime**: bash only; Arch Linux / makepkg toolchain (`bsdtar`, `namcap`, `docker` for CI validation, `asar` npm tool as makedepends). No Node project, no package.json, no bundler.
- **Package deps** (must stay aligned with what the app needs): `electron41`, `python` + reportlab/lxml/pillow/defusedxml, `libstdc++`, `nodejs`, `libgcc`, `ripgrep`, `xdg-utils`; makedepends `asar`.
- **Constraints**: `arch=('x86_64')` only. No shellcheck/shfmt configured in CI — validation is `bash -n` + namcap. No formatter/linter config files exist; match surrounding style by hand.

## Testing & QA

No unit tests exist; verification is build-and-run:

1. `bash -n PKGBUILD` and `namcap PKGBUILD` (CI also runs namcap in docker, checks `source`/`sha256sums` array lengths match, each sha256 is `SKIP` or 64-hex, and aborts on any `E:` line).
2. `makepkg` must complete: `.deb` download verifies sha256, `_check_electron_version()` warns on electron mismatch.
3. Smoke test: `zcode` launches, deep-link `zcode://` registration works, taskbar icon groups correctly (`CHROME_DESKTOP`).
4. Update flow end-to-end: `./zcode-update-checker.sh --update` then `makepkg --printsrcinfo >| .SRCINFO`, and confirm PKGBUILD/.SRCINFO agree (CI enforces this).

ZCode itself is proprietary (license `LicenseRef-ZCode`); only the PKGBUILD and scripts are MIT (Copyright 2026 Anyi_QWQ).
