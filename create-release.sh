#!/bin/bash

# Helper script to create a release tag and push to GitHub
# Usage: ./create-release.sh 1.52.4 "Release notes here"

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ -z "$1" ]; then
    echo "❌ Usage: ./create-release.sh <version> [release-notes]"
    echo ""
    echo "Examples:"
    echo "  ./create-release.sh 1.52.4"
    echo "  ./create-release.sh 1.52.4 'Add iOS support, fix build issues'"
    exit 1
fi

VERSION="$1"
RELEASE_NOTES="${2:-Release version $VERSION}"

# Validate version format
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Invalid version format. Use semantic versioning (e.g., 1.52.4)"
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
