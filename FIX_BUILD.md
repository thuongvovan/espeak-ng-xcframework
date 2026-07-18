# Fix Build & Release XCFramework

## ✅ Lỗi Build Được Sửa

### Vấn đề
```
error: call to undeclared function 'le16toh'
error: call to undeclared function 'le32toh'
```

### Giải pháp
**File:** `src/libespeak-ng/spect.c`

Thêm fallback implementations cho `le16toh` và `le32toh`:
- Sử dụng `libkern/OSByteOrder.h` trên macOS (Apple platforms)
- Thêm generic fallback cho các hệ thống khác

---

## ✅ Workflow Được Đơn Giản Hóa

**File:** `.github/workflows/build-xcframework.yml`

- ✅ Build XCFramework trên tag push → Tạo Release
- ✅ Xóa artifact upload (chỉ cần release)
- ✅ Xóa log steps không cần thiết
- ✅ Tập trung vào build + release chính

---

## 🚀 Cách Dùng

### Tạo Release:
```bash
./create-release.sh 1.52.4
```

### Hoặc tạo tag thủ công:
```bash
git tag -a v1.52.4 -m "Fix endian functions"
git push origin v1.52.4
```

GitHub Actions sẽ **tự động**:
1. Build XCFramework
2. Tạo Release
3. Upload asset

---

## 📍 Các Files Thay Đổi

1. `src/libespeak-ng/spect.c` - Fix endian function declarations
2. `.github/workflows/build-xcframework.yml` - Simplified workflow

---

## ✨ Ready to Release

Commit changes và tạo release:
```bash
git add .
git commit -m "fix: add endian function fallback for iOS cross-compilation"
git push origin master

./create-release.sh 1.52.4
```

🎉 Done!
