# ZCode-bin AUR Package

Arch Linux PKGBUILD for [ZCode](https://zcode.z.ai/) - AI-powered code editor by ZAI.

**Current version:** 3.0.1

## How It Works

Since ZCode 3.0.0, the upstream no longer publishes Linux AppImages. This PKGBUILD builds a Linux package by combining:

1. **Electron 41.0.3** Linux runtime (from [official Electron releases](https://github.com/electron/electron/releases))
2. **ZCode 3.0.1** application resources extracted from the macOS DMG (platform-independent `app.asar` and JS-based agent core)
3. **Linux native modules** (`node-pty`) installed via npm

## Installation

### From AUR (推荐)

```bash
yay -S zcode-bin
# or
paru -S zcode-bin
```

### Manual Build

```bash
git clone https://aur.archlinux.org/zcode-bin.git
cd zcode-bin
makepkg -si
```

## Dependencies

- `zlib` - Compression library
- `hicolor-icon-theme` - Icon theme
- `ripgrep` - Fast search tool (symlinked into ZCode)
- `npm` - Node.js package manager (build only)
- `p7zip` - Archive extraction (build only)
- `unzip` - ZIP extraction (build only)

## Files

- `PKGBUILD` - Arch Linux package build script
- `zcode.desktop` - Desktop entry file
- `zcode-update-checker.sh` - Version checker and updater script
- `.github/workflows/update-aur.yml` - GitHub Actions CI workflow

## Troubleshooting

### Version Check Fails

1. Check CDN accessibility:
   ```bash
   curl -I https://cdn.zcode-ai.com/zcode/electron/releases/
   ```
2. Check changelog:
   ```bash
   curl -sL https://zcode.z.ai/en/changelog | grep -oP '[0-9]+\.[0-9]+\.[0-9]+'
   ```
3. Run with verbose output:
   ```bash
   bash -x ./zcode-update-checker.sh
   ```

### App Crashes on Startup

1. Clear cache: `rm -rf ~/.cache/ZCode`
2. Clear config: `rm -rf ~/.config/ZCode`
3. Launch from terminal to see errors: `zcode-bin --no-sandbox`

### Native Module Issues

If node-pty fails to load, rebuild it:
```bash
cd /opt/zcode/resources/app.asar.unpacked
npm rebuild --update-binary
```

## License

This PKGBUILD repository is licensed under the [MIT License](LICENSE).

**Note**: ZCode itself is proprietary software owned by Beijing Zhipu Huazhang Technology Co., Ltd. (北京智谱华章科技股份有限公司) and is subject to its own [license terms](https://zcode.z.ai/terms). This repository only contains the packaging scripts to install ZCode on Arch Linux.

## Links

- [ZCode Official](https://zcode.z.ai/)
- [Changelog](https://zcode.z.ai/en/changelog)
- [GitHub Repository](https://github.com/Anyi-qaq/Zcode-bin)
