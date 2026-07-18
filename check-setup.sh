#!/bin/bash

# Verify CI/CD auto-versioning & release setup

echo "🔍 Kiểm tra Auto-Versioning Setup..."
echo ""

# Check workflow file
if [ -f ".github/workflows/build-xcframework.yml" ]; then
    echo "✅ Workflow: .github/workflows/build-xcframework.yml"
else
    echo "❌ Workflow file not found!"
    exit 1
fi

# Check git repo
if [ -d ".git" ]; then
    echo "✅ Git repository: $(git remote get-url origin)"
else
    echo "❌ Not a git repository!"
    exit 1
fi

# Check dependencies
echo ""
echo "🔍 Kiểm tra dependencies..."
command -v autoconf &>/dev/null && echo "✅ autoconf" || echo "⚠️  autoconf missing"
command -v automake &>/dev/null && echo "✅ automake" || echo "⚠️  automake missing"
command -v libtool &>/dev/null && echo "✅ libtool" || echo "⚠️  libtool missing"

# Show auto-version format
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ Auto-Versioning Ready!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
COMMIT_ID=$(git rev-parse --short HEAD)
AUTO_VERSION="1.52.3-${COMMIT_ID}"
echo ""
echo "📌 Version Format (commit-id based):"
echo "   $AUTO_VERSION"
echo ""
echo "📌 How it works:"
echo "   1. git push origin master"
echo "   2. GitHub Actions auto-builds & auto-releases"
echo "   3. Tag created: v${AUTO_VERSION}"
echo "   4. Release available on GitHub"
echo ""
echo "🚀 Next: Just commit & push!"
echo ""


