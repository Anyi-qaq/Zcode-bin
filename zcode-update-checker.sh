#!/bin/bash
#
# zcode-update-checker.sh
# Monitor ZCode updates and auto-update PKGBUILD
#
# Usage:
#   ./zcode-update-checker.sh              # Check for updates
#   ./zcode-update-checker.sh --update     # Check and update PKGBUILD
#   ./zcode-update-checker.sh --notify     # Check and send notification
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_FILE="${SCRIPT_DIR}/PKGBUILD"
CDN_BASE_URL="https://cdn.codegeex.cn/zcode/electron/releases"
CHANGELOG_URL="https://zcode.z.ai/en/changelog"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log functions (output to stderr to avoid interfering with function return values)
log_info() { echo -e "${BLUE}[INFO]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[OK]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Get current version
get_current_version() {
    if [ -f "$PKGBUILD_FILE" ]; then
        grep '^pkgver=' "$PKGBUILD_FILE" | cut -d'=' -f2 | tr -d '"'
    else
        echo ""
    fi
}

# Get latest version from CDN
get_latest_version_from_cdn() {
    log_info "正在从 CDN 检查最新版本..."
    
    # Try to get CDN directory listing (supports --insecure for certificate issues)
    local versions
    versions=$(curl -sL --max-time 10 --insecure \
        -H "User-Agent: $USER_AGENT" \
        "$CDN_BASE_URL/" 2>/dev/null | \
        grep -oP 'href="\K[0-9]+\.[0-9]+\.[0-9]+' | \
        sort -V | \
        uniq)
    
    if [ -n "$versions" ]; then
        echo "$versions" | tail -1
        return 0
    fi
    
    return 1
}

# Get latest version from Changelog
get_latest_version_from_changelog() {
    log_info "正在从变更日志检查最新版本..."
    
    local version
    version=$(curl -sL --max-time 10 --insecure \
        -H "User-Agent: $USER_AGENT" \
        "$CHANGELOG_URL" 2>/dev/null | \
        grep -oP '[0-9]+\.[0-9]+\.[0-9]+(?=</h2>|</h3>|</div>|</span>)' | \
        head -1)
    
    if [ -n "$version" ]; then
        echo "$version"
        return 0
    fi
    
    return 1
}

# Get latest version (try multiple methods)
get_latest_version() {
    local version=""
    
    # Method 1: CDN directory
    version=$(get_latest_version_from_cdn) || true
    
    # Method 2: Changelog page
    if [ -z "$version" ]; then
        version=$(get_latest_version_from_changelog) || true
    fi
    
    # Method 3: Try common version numbers directly
    if [ -z "$version" ]; then
        log_warn "无法获取远程版本，正在尝试猜测版本号..."
        local current=$(get_current_version)
        if [ -n "$current" ]; then
            # Try incrementing version number
            local major minor patch
            IFS='.' read -r major minor patch <<< "$current"
            
            # Try patch+1
            local next_patch="${major}.${minor}.$((patch + 1))"
            if curl -sI --max-time 5 "$CDN_BASE_URL/${next_patch}/ZCode-${next_patch}-linux-x64.AppImage" | grep -q "200 OK"; then
                version="$next_patch"
            fi
            
            # Try minor+1
            if [ -z "$version" ]; then
                local next_minor="${major}.$((minor + 1)).0"
                if curl -sI --max-time 5 "$CDN_BASE_URL/${next_minor}/ZCode-${next_minor}-linux-x64.AppImage" | grep -q "200 OK"; then
                    version="$next_minor"
                fi
            fi
        fi
    fi
    
    echo "$version"
}

# Calculate file sha256sum
calculate_sha256() {
    local file="$1"
    if command -v sha256sum &>/dev/null; then
        sha256sum "$file" | cut -d' ' -f1
    elif command -v shasum &>/dev/null; then
        shasum -a 256 "$file" | cut -d' ' -f1
    else
        log_error "未找到 sha256 工具"
        return 1
    fi
}

# Download file and calculate checksum
download_and_checksum() {
    local version="$1"
    local url="$CDN_BASE_URL/${version}/ZCode-${version}-linux-x64.AppImage"
    local temp_file="/tmp/zcode-${version}.AppImage"
    
    log_info "正在下载 ZCode ${version}..."
    log_info "URL: $url"
    
    if ! curl -L --max-time 300 \
        -H "User-Agent: $USER_AGENT" \
        --progress-bar \
        -o "$temp_file" \
        "$url"; then
        log_error "下载失败"
        rm -f "$temp_file"
        return 1
    fi
    
    log_info "正在计算校验和..."
    local checksum
    checksum=$(calculate_sha256 "$temp_file")
    
    log_success "下载完成"
    echo "${checksum}|${temp_file}"
}

# Update PKGBUILD
update_pkgbuild() {
    local new_version="$1"
    local checksum="$2"
    local temp_file="$3"
    local new_pkgbuild="${PKGBUILD_FILE}.new"
    
    log_info "正在更新 PKGBUILD 到版本 ${new_version}..."
    
    # Read current PKGBUILD
    if [ ! -f "$PKGBUILD_FILE" ]; then
        log_error "未找到 PKGBUILD: $PKGBUILD_FILE"
        return 1
    fi
    
    # Update version and checksum
    sed -i \
        -e "s/^pkgver=.*/pkgver=${new_version}/" \
        -e "s/^pkgrel=.*/pkgrel=1/" \
        -e "s/sha256sums=('.*')/sha256sums=('${checksum}')/" \
        "$PKGBUILD_FILE"
    
    log_success "PKGBUILD 已更新"
    
    # Move downloaded file to correct location
    local target_file="${SCRIPT_DIR}/ZCode-${new_version}-linux-x64.AppImage"
    mv "$temp_file" "$target_file"
    chmod +x "$target_file"
    
    # Remove old version files
    local current_version
    current_version=$(get_current_version)
    if [ -n "$current_version" ] && [ "$current_version" != "$new_version" ]; then
        local old_file="${SCRIPT_DIR}/ZCode-${current_version}-linux-x64.AppImage"
        if [ -f "$old_file" ]; then
            log_info "正在删除旧版本: ${old_file}"
            rm -f "$old_file"
        fi
    fi
    
    return 0
}

# Send system notification
send_notification() {
    local title="$1"
    local message="$2"
    
    if [ -n "${GITHUB_ACTIONS:-}" ]; then
        echo "::notice title=${title}::${message}"
        return 0
    fi
    
    # Try multiple notification methods
    if command -v notify-send &>/dev/null; then
        notify-send "$title" "$message"
    elif command -v zenity &>/dev/null; then
        zenity --info --title="$title" --text="$message"
    elif [ -n "${DISPLAY:-}" ] && command -v xmessage &>/dev/null; then
        echo "$message" | xmessage -file - &
    else
        echo -e "\n${YELLOW}=== $title ===${NC}"
        echo "$message"
    fi
}

# Show version info
show_version_info() {
    local current="$1"
    local latest="$2"
    
    echo ""
    echo "========================================"
    echo "  ZCode 版本检查"
    echo "========================================"
    echo "  当前版本:  ${current:-未安装}"
    echo "  最新版本:  ${latest:-未知}"
    echo "========================================"
    
    if [ -n "$current" ] && [ -n "$latest" ]; then
        if [ "$current" = "$latest" ]; then
            echo -e "  状态:   ${GREEN}已是最新 ✓${NC}"
        else
            echo -e "  状态:   ${YELLOW}发现新版本！${NC}"
            echo -e "  操作:   使用 --update 参数自动更新"
        fi
    fi
    echo ""
}

# Main function
main() {
    local auto_update=false
    local notify=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --update|-u)
                auto_update=true
                shift
                ;;
            --notify|-n)
                notify=true
                shift
                ;;
            --help|-h)
                echo "用法: $0 [选项]"
                echo ""
                echo "选项:"
                echo "  --update, -u    检查并自动更新 PKGBUILD"
                echo "  --notify, -n    发现新版本时发送系统通知"
                echo "  --help, -h      显示此帮助信息"
                echo ""
                echo "示例:"
                echo "  $0                    # 仅检查更新"
                echo "  $0 --update           # 检查并更新 PKGBUILD"
                echo "  $0 --notify           # 检查并发送通知"
                echo "  $0 --update --notify  # 更新并发送通知"
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                exit 1
                ;;
        esac
    done
    
    # Get version info
    local current_version
    current_version=$(get_current_version)
    
    local latest_version
    latest_version=$(get_latest_version)
    
    # Show version info
    show_version_info "$current_version" "$latest_version"
    
    # Check if version was obtained
    if [ -z "$latest_version" ]; then
        log_error "无法确定最新版本"
        exit 1
    fi
    
    # Compare versions
    if [ -n "$current_version" ] && [ "$current_version" = "$latest_version" ]; then
        log_success "ZCode 已是最新版本 (${current_version})"
        exit 0
    fi
    
    # New version available
    log_warn "发现新版本: ${latest_version}"
    
    # Send notification
    if [ "$notify" = true ]; then
        send_notification "ZCode 发现新版本" \
            "新版本: ${latest_version}\n当前版本: ${current_version:-未安装}\n\n使用 --update 参数自动更新。"
    fi
    
    # Auto update
    if [ "$auto_update" = true ]; then
        log_info "开始自动更新..."
        
        # Download and calculate checksum
        local result
        if ! result=$(download_and_checksum "$latest_version"); then
            log_error "下载新版本失败"
            exit 1
        fi
        
        local checksum="${result%|*}"
        local temp_file="${result#*|}"
        
        log_info "校验和: ${checksum}"
        
        # Update PKGBUILD
        if update_pkgbuild "$latest_version" "$checksum" "$temp_file"; then
            log_success "更新完成！"
            log_info "新 PKGBUILD 版本: ${latest_version}"
            log_info "执行 'makepkg -si' 即可构建并安装"
            
            if [ "$notify" = true ]; then
                send_notification "ZCode 已更新" \
                    "已成功更新至版本 ${latest_version}\n执行 'makepkg -si' 即可安装。"
            fi
        else
            log_error "更新 PKGBUILD 失败"
            rm -f "$temp_file"
            exit 1
        fi
    else
        log_info "使用 --update 参数可自动更新 PKGBUILD"
    fi
}

# 运行Main function
main "$@"
