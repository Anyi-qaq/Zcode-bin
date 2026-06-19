# ZCode-bin AUR Package

Arch Linux PKGBUILD for [ZCode](https://zcode.z.ai/) - AI-powered code editor by ZAI.

**Current version:** 3.1.2

## How It Works

Since ZCode 3.1+, upstream publishes Linux `.deb` packages directly. This PKGBUILD simply extracts the `.deb` and repackages it for Arch Linux. No more cross-platform assembly needed.

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

| Package | Purpose |
|---------|---------|
| `gtk3` | GUI toolkit |
| `nss` | Network security (Chromium) |
| `libnotify` | Desktop notifications |
| `libxss` | X11 screen saver |
| `libxtst` | X11 input testing |
| `xdg-utils` | xdg-open, xdg-mime |
| `libsecret` | Password/keyring storage |
| `hicolor-icon-theme` | Icon theme |

## Files

- `PKGBUILD` - Arch Linux package build script
- `zcode-bin.install` - Post-install hooks (desktop/MIME integration)
- `zcode-update-checker.sh` - Version checker and updater script
- `.github/workflows/update-aur.yml` - GitHub Actions CI workflow

## Troubleshooting

### App Crashes on Startup

1. Clear cache: `rm -rf ~/.cache/ZCode`
2. Clear config: `rm -rf ~/.config/ZCode`
3. Launch from terminal to see errors: `zcode-bin`

## License

This PKGBUILD repository is licensed under the [MIT License](LICENSE).

**Note**: ZCode itself is proprietary software owned by Beijing Zhipu Huazhang Technology Co., Ltd. (北京智谱华章科技股份有限公司) and is subject to its own [license terms](https://zcode.z.ai/terms). This repository only contains the packaging scripts to install ZCode on Arch Linux.

## Links

- [ZCode Official](https://zcode.z.ai/)
- [Changelog](https://zcode.z.ai/en/changelog)
- [GitHub Repository](https://github.com/Anyi-qaq/Zcode-bin)
