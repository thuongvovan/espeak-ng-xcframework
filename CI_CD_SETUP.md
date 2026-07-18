# CI/CD Setup: Tự động Build XCFramework & Release trên GitHub

## 📋 Tổng quan

Dự án đã được thiết lập để tự động build xcframework và release lên GitHub khi commit. Quá trình này hoàn toàn tự động thông qua GitHub Actions.

## 🚀 Cách sử dụng

### 1. **Tự động Build trên mỗi Commit**

Khi bạn push code lên `master` branch:
```bash
git commit -m "Your changes"
git push origin master
```

✅ GitHub Actions sẽ **tự động**:
- Build XCFramework
- Lưu artifact trong Actions (30 ngày)

### 2. **Tạo Release trên GitHub**

Để tạo một release chính thức (với version tag), sử dụng script helper:

```bash
./create-release.sh 1.52.4
```

Hoặc với ghi chú chi tiết:

```bash
./create-release.sh 1.52.4 "Add iOS support, fix xcframework issues"
```

✅ GitHub Actions sẽ **tự động**:
- Build XCFramework
- Tạo GitHub Release
- Upload xcframework.tar.gz đến release assets
- Tạo release notes

### 3. **Tạo Tag thủ công (nếu cần)**

Nếu muốn tạo tag trực tiếp:

```bash
git tag -a v1.52.4 -m "Release version 1.52.4"
git push origin v1.52.4
```

## 📦 Artifacts

### Trên Commits thường:
- Artifact: `ESpeakNG-1.52.3.tar.gz` (tìm trong Actions tab)
- Lưu trữ: 30 ngày

### Trên Release Tags:
- Release Asset: `ESpeakNG.xcframework.tar.gz`
- Lưu trữ vĩnh viễn
- URL: `https://github.com/YOUR_ORG/espeak-ng-xcframework/releases/tag/v1.52.4`

## 📁 Workflow Files

- `.github/workflows/build-xcframework.yml` - Main build & release workflow
- `.github/workflows/ci.yml` - Existing CI pipeline (unchanged)

## 🔧 Xem status Build

### Trên GitHub:
1. Vào repository
2. Click tab **Actions**
3. Chọn workflow "Build & Release XCFramework"
4. Xem logs chi tiết

### Trên Terminal:
```bash
# Xem git log với tags
git log --oneline --decorate

# Xem danh sách tags
git tag -l

# Xem chi tiết một tag
git show v1.52.4
```

## 🎯 Quy trình Recommended

### Để develop:
```bash
# 1. Commit changes
git add .
git commit -m "Fix: your changes"
git push origin master

# 2. GitHub Actions tự động build
# 3. Kiểm tra artifact trong Actions tab
```

### Để release:
```bash
# 1. Commit tất cả changes
git add .
git commit -m "Prepare v1.52.4 release"
git push origin master

# 2. Tạo release tag
./create-release.sh 1.52.4 "Add iOS 17 support, improve build performance"

# 3. GitHub Actions tự động:
#    - Build XCFramework
#    - Tạo Release trên GitHub
#    - Upload artifacts
```

## 📊 Xem Release History

```bash
# Xem tất cả releases
git tag -l

# Xem release notes của một tag
git show v1.52.4

# Trên GitHub: 
# https://github.com/YOUR_ORG/espeak-ng-xcframework/releases
```

## 🐛 Troubleshooting

### Build thất bại?
1. Kiểm tra Actions logs
2. Xem error message chi tiết
3. Verify dependencies: `brew install autoconf automake libtool`
4. Manual test: `./build_xcframework.sh`

### Không tìm thấy artifact?
- Commit builds: Kiểm tra Actions tab → Artifacts
- Release builds: GitHub Releases page

### Muốn skip build?
Thêm `[skip ci]` vào commit message:
```bash
git commit -m "docs: update README [skip ci]"
```

## 🔑 Requirements

- ✅ Xcode Command Line Tools
- ✅ Homebrew packages: `autoconf automake libtool`
- ✅ macOS 14+
- ✅ GitHub token (tự động qua GitHub Actions)

## 📝 Cấu hình Version

Version hiện tại trong `build_xcframework.sh`:
```bash
VERSION="1.52.3"
```

Để cập nhật version mặc định:
```bash
# Sửa file
sed -i '' 's/VERSION="1.52.3"/VERSION="1.52.4"/' build_xcframework.sh
```

## 🔗 Useful Links

- [GitHub Actions Documentation](https://docs.github.com/actions)
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release)
- [Semantic Versioning](https://semver.org/)

## ✨ Tóm tắt

| Hành động | Kết quả | Nơi tìm |
|-----------|--------|---------|
| `git push origin master` | Auto build | Actions tab → Artifacts (30 days) |
| `./create-release.sh 1.52.4` | Build + Release | GitHub Releases page (permanent) |
| Tag push | Build + Release | GitHub Releases page (permanent) |

---

🎉 **Dự án đã sẵn sàng cho CI/CD tự động!**
