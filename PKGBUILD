pkgname=zcode-bin
pkgver=3.0.1
pkgrel=1
pkgdesc="ZCode - AI-powered code editor by CodeGeeX"
arch=('x86_64')
url="https://zcode.z.ai/"
license=('MIT' 'custom:ZCode')
depends=('zlib' 'hicolor-icon-theme' 'ripgrep')
makedepends=('npm' 'p7zip' 'unzip')
options=('!strip')
install=zcode-bin.install
source=("electron-v41.0.3-linux-x64.zip::https://github.com/electron/electron/releases/download/v41.0.3/electron-v41.0.3-linux-x64.zip"
        "ZCode-${pkgver}-mac-arm64.dmg::https://cdn.zcode-ai.com/zcode/electron/releases/${pkgver}/ZCode-${pkgver}-mac-arm64.dmg"
        "zcode.desktop"
        "zcode-bin.install"
        "LICENSE")
sha256sums=('SKIP'
            'SKIP'
            'SKIP'
            'SKIP'
            'SKIP')

prepare() {
    # Clean up previous extraction to ensure idempotent re-runs
    rm -rf "${srcdir}/electron" "${srcdir}/dmg-extract" "${srcdir}/npm-tmp"

    # Extract Electron 41.0.3 Linux runtime
    mkdir -p "${srcdir}/electron"
    unzip -q "${srcdir}/electron-v41.0.3-linux-x64.zip" -d "${srcdir}/electron"

    # Extract macOS DMG to get 3.0.1 resources (app.asar, glm, etc.)
    7z x "${srcdir}/ZCode-${pkgver}-mac-arm64.dmg" -o"${srcdir}/dmg-extract" -y >/dev/null 2>&1

    # Install Linux native modules for node-pty (not included in macOS DMG)
    mkdir -p "${srcdir}/npm-tmp"
    (cd "${srcdir}/npm-tmp" && npm init -y >/dev/null 2>&1 && npm install @lydell/node-pty-linux-x64@1.2.0-beta.10 >/dev/null 2>&1)
}

package() {
    # ===== Base directory =====
    mkdir -p "${pkgdir}/opt/zcode"
    mkdir -p "${pkgdir}/opt/zcode/resources"

    # ===== Electron 41.0.3 runtime =====
    cp "${srcdir}/electron/electron" "${pkgdir}/opt/zcode/zcode"
    cp "${srcdir}/electron/chrome-sandbox" "${pkgdir}/opt/zcode/chrome-sandbox"
    cp "${srcdir}/electron/chrome_crashpad_handler" "${pkgdir}/opt/zcode/chrome_crashpad_handler"
    cp "${srcdir}/electron/"*.pak "${pkgdir}/opt/zcode/"
    cp "${srcdir}/electron/"*.bin "${pkgdir}/opt/zcode/"
    cp "${srcdir}/electron/"*.dat "${pkgdir}/opt/zcode/"
    cp "${srcdir}/electron/"*.json "${pkgdir}/opt/zcode/"
    cp "${srcdir}/electron/"*.so* "${pkgdir}/opt/zcode/" 2>/dev/null || true
    cp "${srcdir}/electron/LICENSE" "${pkgdir}/opt/zcode/LICENSE.electron.txt"
    cp "${srcdir}/electron/LICENSES.chromium.html" "${pkgdir}/opt/zcode/" 2>/dev/null || true
    cp -r "${srcdir}/electron/locales" "${pkgdir}/opt/zcode/locales"

    # ===== ZCode 3.0.1 resources from macOS DMG =====
    local RES_SRC
    RES_SRC=$(find "${srcdir}/dmg-extract" -path "*/Contents/Resources" -type d | head -1)

    # Main application asar
    cp "${RES_SRC}/app.asar" "${pkgdir}/opt/zcode/resources/app.asar"
    cp "${RES_SRC}/app-update.yml" "${pkgdir}/opt/zcode/resources/app-update.yml"
    cp "${RES_SRC}/icon.png" "${pkgdir}/opt/zcode/resources/icon.png" 2>/dev/null || true
    cp "${RES_SRC}/icon_windows.png" "${pkgdir}/opt/zcode/resources/icon_windows.png" 2>/dev/null || true

    # ZCode Agent core (JS-based, replaces opencode/codex/gemini/acp from 2.x)
    cp -r "${RES_SRC}/glm" "${pkgdir}/opt/zcode/resources/glm"

    # Fix GLM metadata: macOS bundle says "darwin-arm64", correct to "linux-x64"
    # (the zcode.cjs is platform-independent JavaScript, only metadata is wrong)
    sed -i 's/"platform": *"darwin-arm64"/"platform": "linux-x64"/' \
        "${pkgdir}/opt/zcode/resources/glm/.node-bundle-meta.json" 2>/dev/null || true

    # Model providers catalog
    cp -r "${RES_SRC}/model-providers" "${pkgdir}/opt/zcode/resources/model-providers"

    # ===== Tools directory =====
    mkdir -p "${pkgdir}/opt/zcode/resources/tools/ripgrep"
    # Symlink system ripgrep (depend on ripgrep package)
    ln -sf /usr/bin/rg "${pkgdir}/opt/zcode/resources/tools/ripgrep/rg"

    # ===== app.asar.unpacked (native modules) =====
    # Start with macOS version (has correct directory structure with JS wrappers)
    cp -r "${RES_SRC}/app.asar.unpacked" "${pkgdir}/opt/zcode/resources/app.asar.unpacked"

    # Add Linux node-pty native module
    rm -rf "${pkgdir}/opt/zcode/resources/app.asar.unpacked/node_modules/@lydell/node-pty-linux-x64"
    cp -r "${srcdir}/npm-tmp/node_modules/@lydell/node-pty-linux-x64" \
        "${pkgdir}/opt/zcode/resources/app.asar.unpacked/node_modules/@lydell/"

    # Add Linux pty.node to the main node-pty prebuilds dir too (fallback)
    mkdir -p "${pkgdir}/opt/zcode/resources/app.asar.unpacked/node_modules/node-pty/prebuilds/linux-x64"
    cp "${srcdir}/npm-tmp/node_modules/@lydell/node-pty-linux-x64/prebuilds/linux-x64/pty.node" \
        "${pkgdir}/opt/zcode/resources/app.asar.unpacked/node_modules/node-pty/prebuilds/linux-x64/"

    # ===== Fix permissions =====
    find "${pkgdir}/opt/zcode" -type d -exec chmod 755 {} \;
    find "${pkgdir}/opt/zcode" -type f -exec chmod 644 {} \;
    find "${pkgdir}/opt/zcode" -type f \( -name "*.so" -o -name "*.so.*" \) -exec chmod 755 {} \;

    # Restore exec bit on binaries
    chmod 755 "${pkgdir}/opt/zcode/zcode" \
             "${pkgdir}/opt/zcode/chrome-sandbox" \
             "${pkgdir}/opt/zcode/chrome_crashpad_handler"

    # GLM agent core (CommonJS bundle executed by Node.js)
    chmod 755 "${pkgdir}/opt/zcode/resources/glm/zcode.cjs" 2>/dev/null || true

    # ===== Launcher script =====
    install -dm755 "${pkgdir}/usr/bin"
    cat > "${pkgdir}/usr/bin/${pkgname}" << 'LAUNCHER_EOF'
#!/bin/bash
exec /opt/zcode/zcode --no-sandbox "$@"
LAUNCHER_EOF
    chmod +x "${pkgdir}/usr/bin/${pkgname}"

    # ===== Desktop file (with zcode:// protocol handler registration) =====
    # App internally creates ~/.local/share/applications/zcode.desktop at runtime,
    # so we only need one system-level desktop file here.
    install -Dm644 "${srcdir}/zcode.desktop" "${pkgdir}/usr/share/applications/${pkgname}.desktop"

    # ===== Install hook (post_install registers x-scheme-handler/zcode) =====
    # Handled automatically via the install= directive in PKGBUILD

    # ===== Icons (1024x1024 source from macOS DMG) =====
    for size in 16 32 48 64 128 256 512 1024; do
        install -Dm644 "${RES_SRC}/icon.png" \
            "${pkgdir}/usr/share/icons/hicolor/${size}x${size}/apps/zcode.png" 2>/dev/null || true
    done

    # ===== License =====
    install -Dm644 "${srcdir}/LICENSE" "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE"
}
