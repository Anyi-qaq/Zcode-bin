# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is the **AUR packaging repository** for `zcode-bin` — packaging scripts that build a Linux-native ZCode installation from upstream's macOS DMG combined with the Electron Linux runtime. ZCode is an AI-powered code editor (proprietary, by ZAI/CodeGeeX). Since ZCode 3.0.0, upstream no longer publishes Linux builds; this PKGBUILD bridges that gap.

## Build & Test

```bash
# Build and install locally (Arch Linux only)
makepkg -si

# Build without installing (generates .pkg.tar.zst)
makepkg

# Generate/update .SRCINFO (required for AUR)
makepkg --printsrcinfo > .SRCINFO

# Lint the PKGBUILD (requires namcap)
namcap PKGBUILD
namcap zcode-bin-*.pkg.tar.zst

# Check for new upstream versions (dry run)
./zcode-update-checker.sh

# Auto-update PKGBUILD to latest version
./zcode-update-checker.sh --update

# Verbose debug of the update checker
bash -x ./zcode-update-checker.sh
```

## Architecture

The build is a **cross-platform assembly** — it doesn't compile anything; it combines three disparate sources:

1. **Electron Linux runtime** (`electron-v{VERSION}-linux-x64.zip`) — downloaded from GitHub Releases, provides the Chromium-based runtime with native Linux binaries.
2. **ZCode macOS DMG** (`ZCode-{VERSION}-mac-arm64.dmg`) — downloaded from `cdn.zcode-ai.com`, provides platform-independent resources: `app.asar` (the Electron app bundle), `glm/` (JS-based AI agent core, replaces opencode/codex/gemini from 2.x), and `model-providers/`.
3. **Linux native module** (`@lydell/node-pty-linux-x64`) — installed via npm in `prepare()`, replaces the macOS `node-pty` binary in `app.asar.unpacked`.

**Installed layout** (`/opt/zcode/`):
- Electron runtime binaries at the root (the main binary is renamed from `electron` to `zcode`)
- `resources/app.asar` — the ZCode application
- `resources/glm/` — AI agent core (`zcode.cjs` is the entry point; its `.node-bundle-meta.json` platform field is patched from `darwin-arm64` to `linux-x64`)
- `resources/app.asar.unpacked/node_modules/` — native modules with Linux `pty.node`
- `resources/tools/ripgrep/rg` → symlink to `/usr/bin/rg` (system ripgrep)

**Launcher**: `/usr/bin/zcode-bin` is a one-line script that runs `/opt/zcode/zcode --no-sandbox "$@"`.

## Key Files

- **`PKGBUILD`** — the full build definition: `prepare()` downloads and extracts all sources, `package()` assembles them into the final directory tree. Version is tracked in `pkgver=` and `pkgrel=`.
- **`.SRCINFO`** — AUR metadata mirror of PKGBUILD. Must be kept in sync. Regenerate with `makepkg --printsrcinfo > .SRCINFO` after any PKGBUILD change.
- **`zcode-update-checker.sh`** — standalone version checker. Scrapes the ZCode changelog page for latest version, downloads the DMG to extract the bundled Electron version from `Info.plist`, verifies the corresponding Electron Linux zip exists on GitHub, then sed-updates PKGBUILD in place. Called by CI with `--update`.
- **`zcode-bin.install`** — pacman hooks: `post_install`/`post_upgrade` register the `zcode://` MIME protocol handler (via xdg-mime, user mimeapps.list, and gio), update the desktop database, and refresh the GTK icon cache. `post_remove` unregisters.
- **`zcode.desktop`** — desktop entry with `StartupWMClass=ZCode` and `MimeType=x-scheme-handler/zcode`.
- **`.github/workflows/update-aur.yml`** — daily cron workflow that runs `zcode-update-checker.sh --update`, syncs `.SRCINFO`, commits to GitHub, pushes to AUR remote (`ssh://aur@aur.archlinux.org/zcode-bin.git`), and creates a GitHub Release.

## Constraints

- **No Linux builds from upstream** since 3.0.0 — the DMG extraction approach is the only way to get ZCode on Linux.
- **Electron version is coupled to ZCode version** — each ZCode release bundles a specific Electron. The update checker must extract it from the DMG's `Info.plist`.
- **`app.asar` is platform-independent** (JS/CSS/HTML), but native modules (`node-pty`) are not — hence the npm install step for the Linux variant.
- **System ripgrep** is a hard dependency (`depends=('ripgrep')`) — the build symlinks it rather than bundling a binary.
- **SHA256 sums are skipped** (`SKIP`) because the upstream DMG and Electron zip URLs are stable but their checksums would change every release; CI handles freshness verification by checking URL accessibility instead.
