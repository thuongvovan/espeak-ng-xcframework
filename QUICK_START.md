# 🚀 Tự động Build XCFramework & Release GitHub

## ✨ Các file được tạo

```
.github/workflows/
  └── build-xcframework.yml      ← GitHub Actions workflow (TỰ ĐỘNG)

Root directory:
  ├── create-release.sh          ← Script tạo release tag
  ├── check-setup.sh             ← Script kiểm tra setup
  ├── release-helper.sh          ← Bash aliases tiện ích
  └── CI_CD_SETUP.md             ← Tài liệu chi tiết
```

---

## 🔄 Quy Trình Tự Động

### 1️⃣ **COMMIT → AUTO BUILD**

```
Developer commits
       ↓
git push origin master
       ↓
GitHub Actions (tự động)
       ↓
✅ Build XCFramework
   └─ Artifact: build/ESpeakNG.xcframework.tar.gz
       ↓
📦 Upload to Actions Artifacts (30 ngày)
```

**Kiểm tra:**
- Vào GitHub → Actions tab → "Build & Release XCFramework"
- Xem logs và download artifact

---

### 2️⃣ **RELEASE → AUTO BUILD + GITHUB RELEASE**

```
./create-release.sh 1.52.4
       ↓
git tag v1.52.4
git push origin v1.52.4
       ↓
GitHub Actions (tự động)
       ↓
✅ Build XCFramework
✅ Create GitHub Release
✅ Upload XCFramework.tar.gz to Release Assets
       ↓
📦 Release page: github.com/.../releases/tag/v1.52.4 (VĨNH VIỄN)
```

**Kiểm tra:**
- Vào GitHub → Releases tab
- Xem assets và download xcframework

---

## 🎯 Cách Sử Dụng (Từng Bước)

### **Cách 1: Tạo Release Đơn Giản**

```bash
# Step 1: Commit các thay đổi
git add .
git commit -m "Update xcframework build"
git push origin master

# Step 2: Tạo release tag
./create-release.sh 1.52.4

# Done! ✅ GitHub Actions sẽ tự động:
# - Build xcframework
# - Tạo GitHub Release
# - Upload artifacts
```

---

### **Cách 2: Tạo Release Với Ghi Chú Chi Tiết**

```bash
./create-release.sh 1.52.4 "
- Add iOS 17 support
- Fix arm64e build issues  
- Improve performance
- Update dependencies
"
```

---

### **Cách 3: Tạo Tag Thủ Công**

```bash
# Nếu muốn tạo tag trực tiếp mà không dùng script
git tag -a v1.52.4 -m "Release version 1.52.4"
git push origin v1.52.4

# GitHub Actions sẽ tự động chạy!
```

---

## 📊 Workflow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                   GITHUB ACTIONS CI/CD                      │
└─────────────────────────────────────────────────────────────┘

┌─ EVENT: Push to master
│
├─ Trigger: .github/workflows/build-xcframework.yml
│
├─ Runner: macOS 14 (latest)
│
├─ Steps:
│  1. ✅ Checkout code
│  2. ✅ Install dependencies (autoconf, automake, libtool)
│  3. ✅ Build XCFramework (./build_xcframework.sh)
│  4. ✅ Compress: ESpeakNG.xcframework.tar.gz
│  5. ✅ Upload artifact or create release
│
└─ Output:
   ├─ Commit push: 📦 Actions Artifact (30 days)
   └─ Tag push: 🏷️  GitHub Release (permanent)
```

---

## 🛠️ Các Script Tiện Ích

### **1. Tạo Release**
```bash
./create-release.sh 1.52.4 "Release notes"
```
- ✅ Validate version format
- ✅ Check tag doesn't exist
- ✅ Create git tag
- ✅ Push to GitHub
- ✅ Show release URL

### **2. Kiểm Tra Setup**
```bash
./check-setup.sh
```
- ✅ Verify workflow file
- ✅ Check script permissions
- ✅ Check git repository
- ✅ Verify dependencies (autoconf, automake, libtool)

### **3. Build Locally** (Optional)
```bash
./build_xcframework.sh
```
- Output: `build/ESpeakNG.xcframework/`

---

## 📋 Checklist - Bạn Đã Làm Gì

✅ **Tạo GitHub Actions Workflow**
- File: `.github/workflows/build-xcframework.yml`
- Triggers: `push` & `workflow_dispatch`
- Builds XCFramework automatically
- Creates GitHub Releases
- Uploads artifacts

✅ **Tạo Release Helper Script**
- File: `create-release.sh`
- Validates version format
- Creates & pushes git tags
- Shows release URL

✅ **Tạo Setup Check Script**
- File: `check-setup.sh`
- Verifies all components
- Checks dependencies

✅ **Tạo Tài Liệu**
- `CI_CD_SETUP.md` - Chi tiết đầy đủ
- `QUICK_START.md` - Hướng dẫn này

---

## 🚀 Quick Start (3 Bước)

### **Để release mới:**

```bash
# 1. Commit changes
git add .
git commit -m "Your changes"
git push origin master

# 2. Create release
./create-release.sh 1.52.4

# 3. Xem kết quả
# → GitHub Actions starts building
# → Releases page shows new release
```

---

## 🔍 Xem Status Build

### **Trên GitHub:**
1. Repository → **Actions** tab
2. "Build & Release XCFramework" workflow
3. Click run để xem details
4. Xem logs, artifacts, status

### **Trên Terminal:**
```bash
# Xem tags
git tag -l

# Xem release info
git show v1.52.4

# Xem remote branches/tags
git ls-remote origin
```

---

## 📦 Artifacts Location

### **Commit Builds:**
```
GitHub → Actions → "Build & Release XCFramework"
→ [Latest Run] → Artifacts
→ ESpeakNG-1.52.3.tar.gz (30 days)
```

### **Release Builds:**
```
GitHub → Releases → v1.52.4
→ Assets
→ ESpeakNG.xcframework.tar.gz (permanent)
```

---

## 🎓 Tìm Hiểu Thêm

- **GitHub Actions**: https://docs.github.com/actions
- **Semantic Versioning**: https://semver.org
- **XCFramework**: https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle
- **Build Script**: Xem `build_xcframework.sh` để hiểu chi tiết

---

## 💡 Tips

1. **Version Format**: Luôn dùng `MAJOR.MINOR.PATCH` (e.g., `1.52.4`)
2. **Skip Build**: Thêm `[skip ci]` vào commit message
3. **Release Notes**: Ghi chi tiết thay đổi trong release
4. **Test Locally**: Chạy `./build_xcframework.sh` trước khi release

---

## ✅ Tóm Tắt

| Hành động | Kết quả | Nơi tìm |
|-----------|--------|---------|
| `git push master` | Auto build | Actions → Artifacts |
| `./create-release.sh 1.52.4` | Build + Release | GitHub Releases |
| Tag push | Build + Release | GitHub Releases |
| `./check-setup.sh` | Verify setup | Terminal output |

---

## 🎉 Hoàn Tất!

Dự án của bạn giờ đã:
- ✅ Tự động build XCFramework trên mỗi commit
- ✅ Tự động tạo GitHub Releases
- ✅ Tự động upload artifacts

**Tiếp theo:**
```bash
./create-release.sh 1.52.4 "Your release notes"
```

🚀 **Chúc mừng! CI/CD đã sẵn sàng!**
