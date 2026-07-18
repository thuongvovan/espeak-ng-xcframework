#!/bin/bash

# Helper script to create a release tag and push to GitHub
# Auto-versioning: 1.52.3+fork+{version}
# Usage: ./create-release.sh fork+1 "Release notes"
#    or: ./create-release.sh 1.52.3+fork+1 "Release notes"

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_VERSION="1.52.3"

if [ -z "$1" ]; then
    echo "❌ Usage: ./create-release.sh <version-suffix> [release-notes]"
    echo ""
    echo "Examples:"
    echo "  ./create-release.sh fork+1"
    echo "  ./create-release.sh fork+1 'Fix endian issues'"
    echo "  ./create-release.sh 1.52.3+fork+1 'Full version'"
    exit 1
fi

VERSION_INPUT="$1"
RELEASE_NOTES="${2:-Release version}"

# Normalize version format
if [[ "$VERSION_INPUT" =~ ^\+.*$ ]] || [[ "$VERSION_INPUT" == fork* ]]; then
    # Short format: fork+1 or +fork+1 → 1.52.3+fork+1
    VERSION="${BASE_VERSION}${VERSION_INPUT/^+/+}"
else
    # Full format already
    VERSION="$VERSION_INPUT"
fi

# Validate version format
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(\+[a-zA-Z0-9\+\.]+)?$ ]]; then
    echo "❌ Invalid version format: $VERSION"
    echo "Expected format: 1.52.3+fork+1 or similar"
    exit 1
fi

TAG="v$VERSION"

# Check if tag already exists
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "❌ Tag $TAG already exists!"
    exit 1
fi

echo "🔄 Creating release tag: $TAG"
echo "📝 Release notes: $RELEASE_NOTES"

# Create and push the tag
git tag -a "$TAG" -m "$RELEASE_NOTES"
echo "✅ Tag created locally"

echo "🚀 Pushing tag to GitHub..."
git push origin "$TAG"

echo "✅ Release tag pushed! GitHub Actions will now:"
echo "   1. Build the XCFramework"
echo "   2. Create a GitHub Release"
echo "   3. Attach the XCFramework artifact"
echo ""
echo "🔗 Release URL: https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]//' | sed 's/.git$//')/releases/tag/$TAG"

