#!/bin/bash

# Quick setup script for CI/CD
# This verifies the GitHub Actions workflow is ready to go

set -e

echo "🔍 Kiểm tra setup CI/CD..."
echo ""

# Check if workflow file exists
if [ -f ".github/workflows/build-xcframework.yml" ]; then
    echo "✅ Workflow file: .github/workflows/build-xcframework.yml"
else
    echo "❌ Workflow file không tìm thấy!"
    exit 1
fi

# Check if create-release script exists and is executable
if [ -x "./create-release.sh" ]; then
    echo "✅ Release script: ./create-release.sh (executable)"
else
    echo "⚠️  Release script needs to be executable"
    chmod +x "./create-release.sh"
    echo "✅ Fixed: chmod +x ./create-release.sh"
fi

# Check if build script exists and is executable
if [ -x "./build_xcframework.sh" ]; then
    echo "✅ Build script: ./build_xcframework.sh (executable)"
else
    echo "⚠️  Build script needs to be executable"
    chmod +x "./build_xcframework.sh"
    echo "✅ Fixed: chmod +x ./build_xcframework.sh"
fi

# Check if running on a git repository
if [ -d ".git" ]; then
    echo "✅ Git repository: $(git remote get-url origin)"
    echo "✅ Current branch: $(git rev-parse --abbrev-ref HEAD)"
else
    echo "❌ Không phải git repository!"
    exit 1
fi

# Check dependencies
echo ""
echo "🔍 Kiểm tra dependencies..."

if command -v autoconf &> /dev/null; then
    echo "✅ autoconf: $(autoconf --version | head -n1)"
else
    echo "⚠️  autoconf không tìm thấy - cài đặt: brew install autoconf"
fi

if command -v automake &> /dev/null; then
    echo "✅ automake: $(automake --version | head -n1)"
else
    echo "⚠️  automake không tìm thấy - cài đặt: brew install automake"
fi

if command -v libtool &> /dev/null; then
    echo "✅ libtool: $(libtool --version | head -n1)"
else
    echo "⚠️  libtool không tìm thấy - cài đặt: brew install libtool"
fi

# Check auto-versioning
echo ""
echo "🔍 Kiểm tra auto-versioning..."
BUILD_DATE=$(date +%Y%m%d)
COMMIT_COUNT=$(git rev-list --count HEAD)
AUTO_VERSION="1.52.3+fork+${BUILD_DATE}.${COMMIT_COUNT}"
echo "✅ Auto-version format: $AUTO_VERSION"
echo "   (Được generate tự động từ build script)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ Setup CI/CD hoàn tất!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📌 Versioning Scheme:"
echo "   • Auto (mỗi commit): 1.52.3+fork+{YYYYMMDD}.{commit-count}"
echo "   • Release (tag):     1.52.3+fork+{number}"
echo ""
echo "📌 Tiếp theo:"
echo "   1. Commit & push code:"
echo "      git push origin master"
echo ""
echo "   2. Tạo release (cách 1 - shorthand):"
echo "      ./create-release.sh fork+1"
echo ""
echo "   3. Hoặc tạo release (cách 2 - full version):"
echo "      ./create-release.sh 1.52.3+fork+1"
echo ""
echo "   4. Xem status trên GitHub Actions:"
echo "      https://github.com/YOUR_ORG/espeak-ng-xcframework/actions"
echo ""

