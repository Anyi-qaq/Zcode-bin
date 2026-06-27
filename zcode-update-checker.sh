#!/bin/bash
#
# zcode-update-checker.sh
# Auto-detect new ZCode versions and update PKGBUILD.
#
# Since ZCode 3.1+, upstream publishes Linux .deb packages directly.
# This script checks the changelog for new versions, verifies the .deb
# URL is accessible, and updates PKGBUILD in place.
#
# Usage:
#   ./zcode-update-checker.sh              # Check for updates (dry run)
#   ./zcode-update-checker.sh --update     # Check and update PKGBUILD
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_FILE="${SCRIPT_DIR}/PKGBUILD"
DEB_URL_BASE="https://cdn-zcode.z.ai/zcode/electron/releases"
CHANGELOG_URL="https://zcode.z.ai/en/changelog"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"

# ── helpers ──────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()  { echo -e "${BLUE}[INFO]${NC}  $*" >&2; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*" >&2; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

url_exists() {
    local code
    code=$(curl -sIL --max-time 10 -o /dev/null -w '%{http_code}' \
        -H "User-Agent: $USER_AGENT" "$1" 2>/dev/null)
    [ "$code" = "200" ]
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
    for attempt in $(seq 1 5); do
        local next="${major}.${minor}.$((patch + attempt))"
        if url_exists "${DEB_URL_BASE}/${next}/ZCode-${next}-linux-x64.deb"; then
            echo "$next"
            return 0
        fi
    done
    local next_minor="${major}.$((minor + 1)).0"
    if url_exists "${DEB_URL_BASE}/${next_minor}/ZCode-${next_minor}-linux-x64.deb"; then
        echo "$next_minor"
        return 0
    fi
    log_error "无法确定远程版本"
    return 1
}

# ── PKGBUILD updater ─────────────────────────────────────

update_pkgbuild() {
    local new_zcode="$1"

    log_info "更新 PKGBUILD: ZCode ${new_zcode}"

    # Update pkgver and pkgrel
    sed -i "s/^pkgver=.*/pkgver=${new_zcode}/"  "$PKGBUILD_FILE"
    sed -i "s/^pkgrel=.*/pkgrel=1/"             "$PKGBUILD_FILE"

    # Update .deb source URL
    sed -i "s|ZCode-[0-9.]*-linux-x64\.deb|ZCode-${new_zcode}-linux-x64.deb|g" "$PKGBUILD_FILE"
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

    # Verify the .deb exists
    local deb_url="${DEB_URL_BASE}/${latest_ver}/ZCode-${latest_ver}-linux-x64.deb"
    if ! url_exists "$deb_url"; then
        log_error ".deb 不可访问: $deb_url"
        exit 1
    fi
    log_ok ".deb 可访问"

    # Update PKGBUILD
    update_pkgbuild "$latest_ver"

    log_ok "更新完成! ZCode ${latest_ver}"
}

main "$@"
