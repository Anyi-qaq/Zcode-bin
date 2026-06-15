#!/bin/bash
#
# zcode-update-checker.sh
# Auto-detect new ZCode versions and update PKGBUILD.
#
# For 3.x+: ZCode no longer publishes Linux AppImages.
# Instead we download the macOS DMG to extract platform-independent
# resources, combined with the official Electron Linux runtime.
#
# Usage:
#   ./zcode-update-checker.sh              # Check for updates (dry run)
#   ./zcode-update-checker.sh --update     # Check and update PKGBUILD
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_FILE="${SCRIPT_DIR}/PKGBUILD"
DMG_URL_BASE="https://cdn.zcode-ai.com/zcode/electron/releases"
ELECTRON_RELEASES="https://github.com/electron/electron/releases"
CHANGELOG_URL="https://zcode.z.ai/en/changelog"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"

# ── helpers ──────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()  { echo -e "${BLUE}[INFO]${NC}  $*" >&2; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*" >&2; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

url_exists() {
    curl -sIf --max-time 10 -H "User-Agent: $USER_AGENT" "$1" 2>/dev/null | grep -q '200 OK'
}

# ── version helpers ──────────────────────────────────────

get_current_zcode_version() {
    grep '^pkgver=' "$PKGBUILD_FILE" | cut -d'=' -f2 | tr -d '"'
}

get_latest_zcode_version() {
    local version
    # Method 1: scrape changelog page
    log_info "正在从 changelog 获取最新版本..."
    version=$(curl -sL --max-time 10 -H "User-Agent: $USER_AGENT" \
        "$CHANGELOG_URL" 2>/dev/null | \
        grep -oP '[0-9]+\.[0-9]+\.[0-9]+(?=</h2>|</h3>)' | head -1)
    if [ -n "$version" ]; then
        echo "$version"
        return 0
    fi
    # Method 2: try incrementing from current version
    local cur
    cur=$(get_current_zcode_version)
    if [ -z "$cur" ]; then
        log_error "无法确定远程版本"
        return 1
    fi
    local major minor patch
    IFS='.' read -r major minor patch <<< "$cur"
    # Try up to 5 patch bumps, then minor bump
    for attempt in $(seq 1 5); do
        local next="${major}.${minor}.$((patch + attempt))"
        if url_exists "${DMG_URL_BASE}/${next}/ZCode-${next}-mac-arm64.dmg"; then
            echo "$next"
            return 0
        fi
    done
    local next_minor="${major}.$((minor + 1)).0"
    if url_exists "${DMG_URL_BASE}/${next_minor}/ZCode-${next_minor}-mac-arm64.dmg"; then
        echo "$next_minor"
        return 0
    fi
    log_error "无法确定远程版本"
    return 1
}

# ── Electron version extraction ──────────────────────────

get_electron_version_from_dmg() {
    local zcode_ver="$1"
    local dmg_url="${DMG_URL_BASE}/${zcode_ver}/ZCode-${zcode_ver}-mac-arm64.dmg"
    local tmp_dir
    tmp_dir=$(mktemp -d)

    log_info "正在下载 DMG 提取 Electron 版本..."
    # 7z can extract a specific file from the DMG without writing the whole thing?
    # Actually we need to download then extract. On CI this is fine.
    if ! curl -sL --max-time 120 -H "User-Agent: $USER_AGENT" \
        -o "${tmp_dir}/zcode.dmg" "$dmg_url" 2>/dev/null; then
        log_error "下载 DMG 失败"
        rm -rf "$tmp_dir"
        return 1
    fi

    # Extract just the Info.plist from the Electron Framework
    7z x "${tmp_dir}/zcode.dmg" -o"${tmp_dir}/dmg" -y >/dev/null 2>&1 || true

    local plist
    plist=$(find "${tmp_dir}/dmg" -path "*/Electron Framework.framework/*/Resources/Info.plist" 2>/dev/null | head -1)
    if [ -z "$plist" ]; then
        log_error "未找到 Electron Framework Info.plist"
        rm -rf "$tmp_dir"
        return 1
    fi

    local electron_ver
    electron_ver=$(grep -A1 '<key>CFBundleVersion</key>' "$plist" | \
        grep '<string>' | sed 's/.*<string>\(.*\)<\/string>.*/\1/' | tr -d '[:space:]')
    if [ -z "$electron_ver" ]; then
        log_error "无法从 Info.plist 提取 Electron 版本"
        rm -rf "$tmp_dir"
        return 1
    fi

    rm -rf "$tmp_dir"
    echo "$electron_ver"
}

verify_electron_release() {
    local ver="$1"
    url_exists "https://github.com/electron/electron/releases/download/v${ver}/electron-v${ver}-linux-x64.zip"
}

# ── PKGBUILD updater ─────────────────────────────────────

update_pkgbuild() {
    local new_zcode="$1"
    local new_electron="$2"

    log_info "更新 PKGBUILD: ZCode ${new_zcode} + Electron ${new_electron}"

    # Update pkgver and pkgrel
    sed -i "s/^pkgver=.*/pkgver=${new_zcode}/"  "$PKGBUILD_FILE"
    sed -i "s/^pkgrel=.*/pkgrel=1/"             "$PKGBUILD_FILE"

    # Update Electron URL (version appears in source filename and URL)
    sed -i "s|electron-v[0-9.]*-linux-x64\.zip|electron-v${new_electron}-linux-x64.zip|g" "$PKGBUILD_FILE"
    sed -i "s|/download/v[0-9.]*/electron-v|/download/v${new_electron}/electron-v|g" "$PKGBUILD_FILE"

    # Update ZCode DMG URL (version in filename and directory)
    sed -i "s|ZCode-[0-9.]*-mac-arm64\.dmg|ZCode-${new_zcode}-mac-arm64.dmg|g" "$PKGBUILD_FILE"
    sed -i "s|/releases/[0-9.]*/ZCode-|/releases/${new_zcode}/ZCode-|g" "$PKGBUILD_FILE"

    log_ok "PKGBUILD 已更新"
}

# ── main ─────────────────────────────────────────────────

main() {
    local auto_update=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --update|-u) auto_update=true; shift ;;
            --help|-h)
                echo "Usage: $0 [--update]"
                exit 0 ;;
            *) log_error "未知参数: $1"; exit 1 ;;
        esac
    done

    local cur_ver latest_ver
    cur_ver=$(get_current_zcode_version)
    latest_ver=$(get_latest_zcode_version)

    echo ""
    echo "  ZCode 版本检查"
    echo "  ────────────────"
    echo "  当前:  ${cur_ver:-未知}"
    echo "  最新:  ${latest_ver:-未知}"

    if [ -z "$latest_ver" ]; then
        log_error "无法获取最新版本"
        exit 1
    fi

    if [ "$cur_ver" = "$latest_ver" ] && [ "$auto_update" != true ]; then
        log_ok "已是最新版本 ✓"
        exit 0
    fi

    if [ "$auto_update" != true ]; then
        log_warn "发现新版本: ${latest_ver}"
        log_info "使用 --update 自动更新 PKGBUILD"
        exit 0
    fi

    # ── auto update path ──────────────────────────────────
    log_info "开始自动更新..."

    # Step 1: verify the DMG exists
    local dmg_url="${DMG_URL_BASE}/${latest_ver}/ZCode-${latest_ver}-mac-arm64.dmg"
    if ! url_exists "$dmg_url"; then
        log_error "DMG 不可访问: $dmg_url"
        exit 1
    fi
    log_ok "DMG 可访问"

    # Step 2: extract Electron version from the new DMG
    local electron_ver
    electron_ver=$(get_electron_version_from_dmg "$latest_ver")
    log_ok "Electron 版本: ${electron_ver}"

    # Step 3: verify Electron release exists
    if ! verify_electron_release "$electron_ver"; then
        log_error "Electron ${electron_ver} Linux zip 不可访问"
        log_info "URL: https://github.com/electron/electron/releases/download/v${electron_ver}/electron-v${electron_ver}-linux-x64.zip"
        exit 1
    fi
    log_ok "Electron ${electron_ver} Linux zip 可访问"

    # Step 4: update PKGBUILD
    update_pkgbuild "$latest_ver" "$electron_ver"

    log_ok "更新完成! ZCode ${latest_ver} + Electron ${electron_ver}"
}

main "$@"
