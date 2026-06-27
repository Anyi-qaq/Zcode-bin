# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

AUR packaging repository for `zcode-bin` — repackages ZCode's Linux `.deb` for Arch Linux. ZCode is an AI-powered code editor (proprietary, by ZAI).

## Build & Test

```bash
makepkg -si                       # Build and install
makepkg                           # Build only
makepkg --printsrcinfo >| .SRCINFO # Regenerate AUR metadata
namcap PKGBUILD                   # Lint PKGBUILD
namcap zcode-bin-*.pkg.tar.zst    # Lint built package

./zcode-update-checker.sh          # Check for new upstream version
./zcode-update-checker.sh --update # Auto-update PKGBUILD in place
```

## Architecture

Single source: upstream `.deb` from `cdn-zcode.z.ai`. PKGBUILD extracts via `bsdtar`, uses only `resources/` from the deb, and launches via system `electron41` instead of bundling Electron.

**Installed layout** (system Electron approach):
- `/usr/lib/zcode/` — `app.asar`, `glm/` (AI agent), `model-providers/`, `tools/ripgrep/rg`
- `/usr/share/applications/zcode.desktop`
- `/usr/share/icons/hicolor/*/apps/zcode.png`
- `/usr/bin/zcode` — launcher script (calls `electron41` with `app.asar`)

## Key Files

- **`PKGBUILD`** — the only file that matters for building. Downloads `.deb`, extracts `resources/`, patches `app.asar`, creates launcher.
- **`.SRCINFO`** — AUR metadata. Regenerate with `makepkg --printsrcinfo >| .SRCINFO`.
- **`zcode-update-checker.sh`** — scrapes changelog for latest version, verifies `.deb` URL, sed-updates PKGBUILD. Called by CI.
- **`.github/workflows/update-aur.yml`** — daily cron: runs update checker, syncs .SRCINFO, pushes to GitHub + AUR. Needs `AUR_SSH_KEY` secret and `permissions: contents: write`.

## AUR Push

CI pushes only `PKGBUILD` + `.SRCINFO` to AUR. Pacman hooks from `desktop-file-utils`/`gtk3`/`shared-mime-info` handle post-install integration automatically — no install hook needed.

## Gotchas

- `.SRCINFO` tabs must be real tab characters. CI uses `printf '\t'` in sed — never `\\t`.
- `url_exists()` uses `curl -w '%{http_code}'` with `-L` — old `grep '200 OK'` fails on HTTP/2.
- `zsh noclobber` means `>| .SRCINFO` not `> .SRCINFO`.
