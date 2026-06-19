# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is the **AUR packaging repository** for `zcode-bin`. ZCode is an AI-powered code editor (proprietary, by ZAI). Since ZCode 3.1+, upstream publishes Linux `.deb` packages — this PKGBUILD extracts and repackages them for Arch Linux.

## Build & Test

```bash
# Build and install locally (Arch Linux only)
makepkg -si

# Build without installing (generates .pkg.tar.zst)
makepkg

# Generate/update .SRCINFO (required for AUR)
makepkg --printsrcinfo >| .SRCINFO

# Lint the PKGBUILD (requires namcap)
namcap PKGBUILD
namcap zcode-bin-*.pkg.tar.zst

# Check for new upstream versions (dry run)
./zcode-update-checker.sh

# Auto-update PKGBUILD to latest version
./zcode-update-checker.sh --update
```

## Architecture

The PKGBUILD downloads a single source: the upstream `.deb` from `cdn.codegeex.cn`. The `package()` function extracts `data.tar.xz` from the ar archive and copies everything into the package. No compilation, no npm, no cross-platform assembly.

**Installed layout** (from the `.deb`):
- `/opt/ZCode/zcode` — the Electron binary (launched via `/usr/bin/zcode-bin` wrapper)
- `/opt/ZCode/resources/` — `app.asar` (187MB), `glm/` (AI agent core), `model-providers/`, `tools/ripgrep/rg` (static binary)
- `/usr/share/applications/zcode.desktop` — desktop entry (Exec= `/opt/ZCode/zcode %U`)
- `/usr/share/icons/hicolor/*/apps/zcode.png` — icons in multiple sizes
- `/opt/ZCode/resources/app.asar.unpacked/` — native modules for all platforms (linux, darwin)

**Key differences from the old 3.0.x PKGBUILD** (which combined Electron Linux + macOS DMG + npm node-pty):
- Single source: one `.deb` instead of three separate downloads
- No `makedepends` (no npm, p7zip, unzip needed)
- No platform metadata patching (`.node-bundle-meta.json` already says `linux-x64`)
- ripgrep is bundled (static binary), not symlinked from system
- Install path is `/opt/ZCode/` (matches upstream), previously `/opt/zcode/`

## Key Files

- **`PKGBUILD`** — Arch package build script. `package()` extracts the `.deb`'s `data.tar.xz` and fixes permissions.
- **`.SRCINFO`** — AUR metadata mirror. Regenerate with `makepkg --printsrcinfo >| .SRCINFO` after PKGBUILD changes.
- **`zcode-update-checker.sh`** — scrapes ZCode changelog for latest version, verifies the `.deb` URL on `cdn.codegeex.cn`, sed-updates PKGBUILD. Called by CI with `--update`.
- **`zcode-bin.install`** — pacman hooks for desktop database, MIME database, `zcode://` protocol handler registration, and icon cache.
- **`.github/workflows/update-aur.yml`** — daily cron: runs update checker, syncs `.SRCINFO`, commits to GitHub + AUR, creates GitHub Release. Requires `AUR_SSH_KEY` secret.

## CI Gotchas

- **`url_exists()` must use `curl -w '%{http_code}'`** — the old `grep '200 OK'` fails on HTTP/2 (no reason phrase) and on redirects (returns 302). Always test with `-L` to follow redirects.
- **`.SRCINFO` overwrite** — zsh `noclobber` prevents `>` redirect on existing files; use `>|` or `tee`.
- The CI workflow needs `permissions: contents: write` for `GITHUB_TOKEN` to push commits and create releases.
