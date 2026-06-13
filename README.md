# ZCode AUR Package

Arch Linux PKGBUILD for [ZCode](https://codegeex.cn/) - AI-powered code editor by ZAI.

## Installation

### From AUR (推荐)

```bash
yay -S zcode
# or
paru -S zcode
```

### Manual Build

```bash
git clone https://aur.archlinux.org/zcode.git
cd zcode
makepkg -si
```

## Files

- `PKGBUILD` - Arch Linux package build script
- `zcode.desktop` - Desktop entry file
- `zcode-update-checker.sh` - Version checker and updater script
- `.github/workflows/update-aur.yml` - GitHub Actions workflow

## Troubleshooting

### Update Checker Fails

If version check fails:

1. Check CDN accessibility:
   ```bash
   curl -I https://cdn.codegeex.cn/zcode/electron/releases/
   ```

2. Run with verbose output:
   ```bash
   bash -x ./zcode-update-checker.sh
   ```

## License

This PKGBUILD repository is licensed under the [MIT License](LICENSE).

**Note**: ZCode itself is proprietary software owned by Beijing Zhipu Huazhang Technology Co., Ltd. (北京智谱华章科技股份有限公司) and is subject to its own [license terms](https://zcode.z.ai/terms). This repository only contains the packaging scripts to install ZCode on Arch Linux.

## Contributing

1. Fork this repository
2. Create a feature branch
3. Submit a pull request

## Links

- [ZCode Official](https://codegeex.cn/)
- [GitHub Repository](https://github.com/Anyi-qaq/Zcode-bin)
