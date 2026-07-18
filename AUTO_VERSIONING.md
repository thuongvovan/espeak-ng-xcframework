# XCFramework Auto-Versioning & Auto-Release

## 🎯 Quy Trình

**Đơn giản: Chỉ commit & push, còn lại tự động!**

```
git add .
git commit -m "Your changes"
git push origin master
        ↓
GitHub Actions (Automatic)
        ↓
✅ Build XCFramework
✅ Auto-generate version: 1.52.3+fork+20260718.6047
✅ Create tag: v1.52.3+fork+20260718.6047
✅ Create GitHub Release
✅ Upload artifacts
```

---

## 📌 Version Format

**Automatic (mỗi commit):**
```
1.52.3+fork+20260718.6047
       ↑           ↑     ↑
     fork      date   commit-count
```

- `fork` - Đánh dấu đây là fork
- `20260718` - Date YYYYMMDD
- `6047` - Tổng số commits

---

## 🚀 Cách Dùng

### Lần Đầu: Kiểm Tra Setup
```bash
./check-setup.sh
```

### Mỗi Lần: Chỉ Commit & Push
```bash
# 1. Make changes
vim src/libespeak-ng/spect.c

# 2. Commit
git add .
git commit -m "fix: endian functions"

# 3. Push (tất cả tự động)
git push origin master

# ✅ GitHub Actions sẽ:
#    - Build XCFramework
#    - Auto-generate version
#    - Create tag & release
#    - Upload artifacts
```

### Xem Kết Quả
```bash
# See tags
git tag -l

# See releases
# GitHub → Releases tab
# or: https://github.com/thuongvovan/espeak-ng-xcframework/releases
```

---

## 🔧 Files

- `.github/workflows/build-xcframework.yml` - Auto build + release workflow
- `build_xcframework.sh` - Build script (generates version)
- `check-setup.sh` - Verify setup
- `src/libespeak-ng/spect.c` - Fixed endian functions

---

## ✨ Features

✅ **Fully Automatic**
- No manual versioning
- No manual tag creation
- No manual release creation

✅ **Date-Based Versioning**
- `1.52.3+fork+20260718.1`
- `1.52.3+fork+20260718.2`
- `1.52.3+fork+20260719.1` (next day)

✅ **Never Conflicts**
- Fork version separate from upstream
- Clearly marked as `+fork+`

---

## 📊 Example Release History

```
Commit 1: v1.52.3+fork+20260718.6047
Commit 2: v1.52.3+fork+20260718.6048
Commit 3: v1.52.3+fork+20260718.6049
...
Next Day: v1.52.3+fork+20260719.6100
```

---

## 🐛 Troubleshooting

**Build failed?**
```bash
# Check Actions logs
# GitHub → Actions → Latest run

# Or test locally
./build_xcframework.sh
```

**Tag already exists?**
```bash
# Usually not an issue - workflow checks first
# But if needed:
git tag -d v1.52.3+fork+20260718.6047
git push origin --delete v1.52.3+fork+20260718.6047
```

---

## 📚 Related Files

- `build_xcframework.sh` - Contains version generation logic
- `.github/workflows/build-xcframework.yml` - Workflow that drives automation

---

## ✨ That's it!

Just commit & push. Everything else happens automatically! 🎉
