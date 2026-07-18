#!/bin/bash

# Quick release helper - creates a release in one command
# Usage: source release-helper.sh

alias release='./create-release.sh'
alias check='./check-setup.sh'
alias build-local='./build_xcframework.sh'

echo "✅ Release helpers loaded!"
echo ""
echo "Các lệnh có sẵn:"
echo "  release <version> [notes]    - Tạo release tag"
echo "  check                         - Kiểm tra setup"
echo "  build-local                   - Build xcframework locally"
echo ""
echo "Ví dụ:"
echo "  release 1.52.4 'Add iOS 17 support'"
echo "  check"
echo "  build-local"
echo ""
