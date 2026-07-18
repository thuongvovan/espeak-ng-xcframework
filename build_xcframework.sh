#!/bin/bash
set -e

# Build script for ESpeakNG.xcframework with iOS and macOS support (arm64 + x86_64)

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_DIR="$SCRIPT_DIR/build"
FRAMEWORK_NAME="ESpeakNG"
FRAMEWORK_EXECUTABLE="$FRAMEWORK_NAME"
XCFRAMEWORK_NAME="ESpeakNG.xcframework"
BUNDLE_IDENTIFIER="org.espeakng.xcframework"

# Auto-generate version: 1.52.3-{short-commit-hash}
BASE_VERSION="1.52.3"
COMMIT_ID=$(cd "$SCRIPT_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "dev")
VERSION="${BASE_VERSION}-${COMMIT_ID}"

MIN_MACOS_VERSION="14.0"
MIN_IOS_VERSION="17.0"
MIN_MAC_CATALYST_VERSION="$MIN_MACOS_VERSION"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[BUILD]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

verify_plist_executable() {
    local plist_path="$1"
    local expected="$2"

    if [ ! -f "$plist_path" ]; then
        error "Missing Info.plist at $plist_path"
    fi

    local actual
    actual=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist_path" 2>/dev/null || true)
    if [ "$actual" != "$expected" ]; then
        error "Expected CFBundleExecutable=\"$expected\" in $plist_path but found \"$actual\""
    fi
}

# Verify that a framework symlink matches Apple's expected macOS layout.
# App Store validation enforces `Framework.framework/ESpeakNG -> Versions/Current/ESpeakNG`
# (and the companion Headers/Modules/Resources symlinks), so we fail fast here if the
# structure drifts.
verify_symlink() {
    local link_path="$1"
    local expected_target="$2"

    if [ ! -L "$link_path" ]; then
        error "Expected symlink at $link_path"
    fi

    local actual_target
    actual_target=$(readlink "$link_path")
    if [ "$actual_target" != "$expected_target" ]; then
        error "Symlink $link_path points to \"$actual_target\"; expected \"$expected_target\""
    fi
}

# Ensure the macOS binary remains ad-hoc signed. Shipping a pre-signed v1 binary triggers
# Apple review errors; letting the host app resign the framework is the supported path.
verify_adhoc_signature() {
    local binary_path="$1"

    if [ ! -f "$binary_path" ]; then
        error "Expected binary at $binary_path"
    fi

    local codesign_info
    if ! codesign_info=$(codesign -dv --verbose=4 "$binary_path" 2>&1); then
        error "codesign failed for $binary_path"
    fi

    if ! grep -q "Signature=adhoc" <<< "$codesign_info"; then
        error "Binary $binary_path is not using an ad-hoc signature"
    fi
}

verify_macos_framework() {
    local framework_path="$1"
    local binary_rel="Versions/A/$FRAMEWORK_EXECUTABLE"
    local framework_link_target="Versions/Current/$FRAMEWORK_EXECUTABLE"

    log "Verifying macOS framework at $framework_path..."
    verify_plist_executable "$framework_path/Versions/A/Resources/Info.plist" "$FRAMEWORK_EXECUTABLE"
    verify_symlink "$framework_path/ESpeakNG" "$framework_link_target"
    verify_symlink "$framework_path/Headers" "Versions/Current/Headers"
    verify_symlink "$framework_path/Modules" "Versions/Current/Modules"
    verify_symlink "$framework_path/Resources" "Versions/Current/Resources"
    verify_symlink "$framework_path/Versions/Current" "A"
    verify_adhoc_signature "$framework_path/$binary_rel"
}

verify_ios_framework() {
    local framework_path="$1"

    log "Verifying iOS framework at $framework_path..."
    verify_plist_executable "$framework_path/Info.plist" "$FRAMEWORK_EXECUTABLE"
    if [ ! -f "$framework_path/$FRAMEWORK_EXECUTABLE" ]; then
        error "Expected binary at $framework_path/$FRAMEWORK_EXECUTABLE"
    fi
    if [ ! -L "$framework_path/ESpeakNG" ] && [ ! -f "$framework_path/ESpeakNG" ]; then
        error "Expected compatibility link at $framework_path/ESpeakNG"
    fi

    if [ ! -d "$framework_path/espeak-ng-data.bundle" ]; then
        error "Missing espeak-ng-data.bundle in $framework_path"
    fi
}

# Clean previous builds
log "Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build for a specific platform
build_platform() {
    local PLATFORM=$1  # macos, ios, iossimulator
    local ARCH=$2      # arm64
    local SDK=$3       # macosx, iphoneos, iphonesimulator
    local MIN_VERSION=$4
    local BUILD_SUBDIR="$BUILD_DIR/build-$PLATFORM-$ARCH"
    local INSTALL_DIR="$BUILD_DIR/install-$PLATFORM-$ARCH"

    log "Building for $PLATFORM ($ARCH)..."

    mkdir -p "$BUILD_SUBDIR"
    mkdir -p "$INSTALL_DIR"

    # Run autogen if configure doesn't exist
    if [ ! -f "$SCRIPT_DIR/configure" ]; then
        log "Running autogen.sh..."
        cd "$SCRIPT_DIR"
        ./autogen.sh
    fi

    # Clean any previous build artifacts
    cd "$SCRIPT_DIR"
    make distclean 2>/dev/null || true

    # Get SDK path
    SDK_PATH=$(xcrun --sdk $SDK --show-sdk-path)

    log "Configuring for $PLATFORM $ARCH (SDK: $SDK)..."

    # Platform-specific flags
    local TARGET_TRIPLE=""
    local MIN_VERSION_FLAG=""
    local DEPLOYMENT_ENV=""
    if [ "$PLATFORM" = "iossimulator" ]; then
        TARGET_TRIPLE="$ARCH-apple-ios$MIN_VERSION-simulator"
        MIN_VERSION_FLAG="-mios-simulator-version-min=$MIN_VERSION"
    elif [ "$PLATFORM" = "ios" ]; then
        TARGET_TRIPLE="$ARCH-apple-ios$MIN_VERSION"
        MIN_VERSION_FLAG="-miphoneos-version-min=$MIN_VERSION"
        DEPLOYMENT_ENV="IPHONEOS_DEPLOYMENT_TARGET"
    else
        TARGET_TRIPLE="$ARCH-apple-macos$MIN_VERSION"
        MIN_VERSION_FLAG="-mmacosx-version-min=$MIN_VERSION"
        DEPLOYMENT_ENV="MACOSX_DEPLOYMENT_TARGET"
    fi

    local COMMON_CFLAGS="-target $TARGET_TRIPLE $MIN_VERSION_FLAG -isysroot $SDK_PATH -O2"
    local COMMON_LDFLAGS="-target $TARGET_TRIPLE $MIN_VERSION_FLAG -isysroot $SDK_PATH"
    local CC_WITH_TARGET="clang -target $TARGET_TRIPLE -isysroot $SDK_PATH"
    local CXX_WITH_TARGET="clang++ -target $TARGET_TRIPLE -isysroot $SDK_PATH"

    local CONFIG_ENV=(
        "SDKROOT=$SDK_PATH"
        "CFLAGS=$COMMON_CFLAGS"
        "CXXFLAGS=$COMMON_CFLAGS"
        "LDFLAGS=$COMMON_LDFLAGS"
        "CC=$CC_WITH_TARGET"
        "CXX=$CXX_WITH_TARGET"
    )
    if [ -n "$DEPLOYMENT_ENV" ]; then
        CONFIG_ENV+=("$DEPLOYMENT_ENV=$MIN_VERSION")
    fi

    env "${CONFIG_ENV[@]}" ./configure \
        --host=$ARCH-apple-darwin \
        --prefix="$INSTALL_DIR" \
        --without-pcaudiolib \
        --without-sonic \
        --without-klatt \
        --without-mbrola \
        --without-speechplayer \
        --without-async \
        --disable-static \
        --enable-shared

    # Build
    log "Compiling for $PLATFORM $ARCH..."
    local BUILD_ENV=("SDKROOT=$SDK_PATH")
    if [ -n "$DEPLOYMENT_ENV" ]; then
        BUILD_ENV+=("$DEPLOYMENT_ENV=$MIN_VERSION")
    fi
    local BUILD_TARGET="all"
    local INSTALL_CMD=("make" "install")
    if [ "$PLATFORM" = "macos" ] && [ "$ARCH" != "arm64" ]; then
        BUILD_TARGET="src/libespeak-ng.la"
        INSTALL_CMD=()
    fi

    if [ "$BUILD_TARGET" = "all" ]; then
        env "${BUILD_ENV[@]}" make -j$(sysctl -n hw.ncpu)
    else
        env "${BUILD_ENV[@]}" make -j$(sysctl -n hw.ncpu) "$BUILD_TARGET"
    fi

    # Install
    if [ "${#INSTALL_CMD[@]}" -eq 0 ]; then
        log "Staging library for $PLATFORM $ARCH (skipping make install)..."
        mkdir -p "$INSTALL_DIR/lib"
        cp "$SCRIPT_DIR/src/.libs/libespeak-ng.1.dylib" "$INSTALL_DIR/lib/libespeak-ng.1.dylib"
    else
        log "Installing for $PLATFORM $ARCH..."
        env "${BUILD_ENV[@]}" "${INSTALL_CMD[@]}"
    fi

    # Save the library
    mkdir -p "$BUILD_SUBDIR"
    if [ "$PLATFORM" = "macos" ]; then
        cp "$INSTALL_DIR/lib/libespeak-ng.1.dylib" "$BUILD_SUBDIR/"
    else
        cp "$INSTALL_DIR/lib/libespeak-ng.1.dylib" "$BUILD_SUBDIR/"
    fi

    # Clean for next build
    make distclean 2>/dev/null || true
}

# Build macOS first (we need this to compile the data)
log "Building macOS platform (will be used to compile espeak-ng-data)..."
build_platform "macos" "arm64" "macosx" "$MIN_MACOS_VERSION"
log "Building macOS platform for Intel (x86_64)..."
build_platform "macos" "x86_64" "macosx" "$MIN_MACOS_VERSION"

# Now build iOS platforms without trying to compile data
log "Building iOS platforms (will reuse espeak-ng-data from macOS build)..."

# Modify configure to skip data compilation for iOS
build_ios_platform() {
    local PLATFORM=$1
    local ARCH=$2
    local SDK=$3
    local MIN_VERSION=$4
    local BUILD_SUBDIR="$BUILD_DIR/build-$PLATFORM-$ARCH"
    local INSTALL_DIR="$BUILD_DIR/install-$PLATFORM-$ARCH"

    log "Building for $PLATFORM ($ARCH)..."

    mkdir -p "$BUILD_SUBDIR"
    mkdir -p "$INSTALL_DIR"

    cd "$SCRIPT_DIR"
    make distclean 2>/dev/null || true

    SDK_PATH=$(xcrun --sdk $SDK --show-sdk-path)

    local TARGET_TRIPLE=""
    local MIN_VERSION_FLAG=""
    local DEPLOYMENT_ENV=""
    if [ "$PLATFORM" = "iossimulator" ]; then
        TARGET_TRIPLE="$ARCH-apple-ios$MIN_VERSION-simulator"
        MIN_VERSION_FLAG="-mios-simulator-version-min=$MIN_VERSION"
    else
        TARGET_TRIPLE="$ARCH-apple-ios$MIN_VERSION"
        MIN_VERSION_FLAG="-miphoneos-version-min=$MIN_VERSION"
        DEPLOYMENT_ENV="IPHONEOS_DEPLOYMENT_TARGET"
    fi

    local COMMON_CFLAGS="-target $TARGET_TRIPLE $MIN_VERSION_FLAG -isysroot $SDK_PATH -O2"
    local COMMON_LDFLAGS="-target $TARGET_TRIPLE $MIN_VERSION_FLAG -isysroot $SDK_PATH"
    local CC_WITH_TARGET="clang -target $TARGET_TRIPLE -isysroot $SDK_PATH"
    local CXX_WITH_TARGET="clang++ -target $TARGET_TRIPLE -isysroot $SDK_PATH"

    local CONFIG_ENV=(
        "SDKROOT=$SDK_PATH"
        "CFLAGS=$COMMON_CFLAGS"
        "CXXFLAGS=$COMMON_CFLAGS"
        "LDFLAGS=$COMMON_LDFLAGS"
        "CC=$CC_WITH_TARGET"
        "CXX=$CXX_WITH_TARGET"
    )
    if [ -n "$DEPLOYMENT_ENV" ]; then
        CONFIG_ENV+=("$DEPLOYMENT_ENV=$MIN_VERSION")
    fi

    log "Configuring for $PLATFORM $ARCH (SDK: $SDK)..."

    env "${CONFIG_ENV[@]}" ./configure \
        --host=$ARCH-apple-darwin \
        --prefix="$INSTALL_DIR" \
        --without-pcaudiolib \
        --without-sonic \
        --without-klatt \
        --without-mbrola \
        --without-speechplayer \
        --without-async \
        --disable-static \
        --enable-shared

    # Build only the library, not the data
    log "Compiling library for $PLATFORM $ARCH..."
    local BUILD_ENV=("SDKROOT=$SDK_PATH")
    if [ -n "$DEPLOYMENT_ENV" ]; then
        BUILD_ENV+=("$DEPLOYMENT_ENV=$MIN_VERSION")
    fi
    env "${BUILD_ENV[@]}" make -j$(sysctl -n hw.ncpu) src/libespeak-ng.la

    # Install
    log "Installing for $PLATFORM $ARCH..."
    if [ "$PLATFORM" = "iossimulator" ] && [ "$ARCH" != "arm64" ]; then
        log "Staging library for $PLATFORM $ARCH (skipping make install)..."
        mkdir -p "$INSTALL_DIR/lib"
        cp "$SCRIPT_DIR/src/.libs/libespeak-ng.1.dylib" "$INSTALL_DIR/lib/libespeak-ng.1.dylib"
    else
        env "${BUILD_ENV[@]}" make install-exec install-espeak_includeHEADERS install-espeak_ng_includeHEADERS
    fi

    # Copy just the library
    mkdir -p "$BUILD_SUBDIR"
    cp "$INSTALL_DIR/lib/libespeak-ng.1.dylib" "$BUILD_SUBDIR/"

    make distclean 2>/dev/null || true
}

build_ios_platform "ios" "arm64" "iphoneos" "$MIN_IOS_VERSION"
build_ios_platform "iossimulator" "arm64" "iphonesimulator" "$MIN_IOS_VERSION"
log "Building iOS Simulator platform for Intel (x86_64)..."
build_ios_platform "iossimulator" "x86_64" "iphonesimulator" "$MIN_IOS_VERSION"

build_maccatalyst_platform() {
    local ARCH=$1
    local IOS_MIN_VERSION=$2
    local MACOS_MIN_VERSION=$3
    local PLATFORM="maccatalyst"
    local SDK="macosx"
    local BUILD_SUBDIR="$BUILD_DIR/build-$PLATFORM-$ARCH"
    local INSTALL_DIR="$BUILD_DIR/install-$PLATFORM-$ARCH"

    log "Building for Mac Catalyst ($ARCH)..."

    mkdir -p "$BUILD_SUBDIR"
    mkdir -p "$INSTALL_DIR"

    cd "$SCRIPT_DIR"
    make distclean 2>/dev/null || true

    SDK_PATH=$(xcrun --sdk $SDK --show-sdk-path)

    local TARGET_TRIPLE="$ARCH-apple-ios${IOS_MIN_VERSION}-macabi"
    local MACOS_MIN_FLAG="-mmacosx-version-min=$MACOS_MIN_VERSION"
    local COMMON_CFLAGS="-target $TARGET_TRIPLE $MACOS_MIN_FLAG -isysroot $SDK_PATH -O2"
    local COMMON_LDFLAGS="-target $TARGET_TRIPLE $MACOS_MIN_FLAG -isysroot $SDK_PATH"
    local CC_WITH_TARGET="clang -target $TARGET_TRIPLE -isysroot $SDK_PATH"
    local CXX_WITH_TARGET="clang++ -target $TARGET_TRIPLE -isysroot $SDK_PATH"

    local CONFIG_ENV=(
        "SDKROOT=$SDK_PATH"
        "CFLAGS=$COMMON_CFLAGS"
        "CXXFLAGS=$COMMON_CFLAGS"
        "LDFLAGS=$COMMON_LDFLAGS"
        "CC=$CC_WITH_TARGET"
        "CXX=$CXX_WITH_TARGET"
        "MACOSX_DEPLOYMENT_TARGET=$MACOS_MIN_VERSION"
        "IPHONEOS_DEPLOYMENT_TARGET=$IOS_MIN_VERSION"
    )

    log "Configuring for Mac Catalyst $ARCH (SDK: $SDK)..."

    env "${CONFIG_ENV[@]}" ./configure \
        --host=$ARCH-apple-darwin \
        --prefix="$INSTALL_DIR" \
        --without-pcaudiolib \
        --without-sonic \
        --without-klatt \
        --without-mbrola \
        --without-speechplayer \
        --without-async \
        --disable-static \
        --enable-shared

    log "Compiling library for Mac Catalyst $ARCH..."
    local BUILD_ENV=(
        "SDKROOT=$SDK_PATH"
        "MACOSX_DEPLOYMENT_TARGET=$MACOS_MIN_VERSION"
        "IPHONEOS_DEPLOYMENT_TARGET=$IOS_MIN_VERSION"
    )
    env "${BUILD_ENV[@]}" make -j$(sysctl -n hw.ncpu) src/libespeak-ng.la

    log "Installing for Mac Catalyst $ARCH..."
    env "${BUILD_ENV[@]}" make install-exec install-espeak_includeHEADERS install-espeak_ng_includeHEADERS

    mkdir -p "$BUILD_SUBDIR"
    cp "$INSTALL_DIR/lib/libespeak-ng.1.dylib" "$BUILD_SUBDIR/"

    make distclean 2>/dev/null || true
}

log "Building Mac Catalyst platforms..."
build_maccatalyst_platform "arm64" "$MIN_IOS_VERSION" "$MIN_MAC_CATALYST_VERSION"
build_maccatalyst_platform "x86_64" "$MIN_IOS_VERSION" "$MIN_MAC_CATALYST_VERSION"

# Create framework for macOS
log "Creating macOS framework..."
MACOS_FRAMEWORK_DIR="$BUILD_DIR/macos/$FRAMEWORK_NAME.framework"
mkdir -p "$MACOS_FRAMEWORK_DIR/Versions/A/Headers"
mkdir -p "$MACOS_FRAMEWORK_DIR/Versions/A/Modules"
mkdir -p "$MACOS_FRAMEWORK_DIR/Versions/A/Resources"

lipo -create \
    "$BUILD_DIR/build-macos-arm64/libespeak-ng.1.dylib" \
    "$BUILD_DIR/build-macos-x86_64/libespeak-ng.1.dylib" \
    -output "$MACOS_FRAMEWORK_DIR/Versions/A/$FRAMEWORK_EXECUTABLE"

install_name_tool -id "@rpath/$FRAMEWORK_NAME.framework/Versions/A/$FRAMEWORK_EXECUTABLE" \
    "$MACOS_FRAMEWORK_DIR/Versions/A/$FRAMEWORK_EXECUTABLE"

# Copy headers
cp "$BUILD_DIR/install-macos-arm64/include/espeak-ng/espeak_ng.h" \
   "$MACOS_FRAMEWORK_DIR/Versions/A/Headers/"
cp "$BUILD_DIR/install-macos-arm64/include/espeak-ng/speak_lib.h" \
   "$MACOS_FRAMEWORK_DIR/Versions/A/Headers/"
cp "$BUILD_DIR/install-macos-arm64/include/espeak-ng/encoding.h" \
   "$MACOS_FRAMEWORK_DIR/Versions/A/Headers/"

# Duplicate headers inside espeak-ng/ to match upstream include paths
mkdir -p "$MACOS_FRAMEWORK_DIR/Versions/A/Headers/espeak-ng"
cp "$BUILD_DIR/install-macos-arm64/include/espeak-ng/"*.h \
   "$MACOS_FRAMEWORK_DIR/Versions/A/Headers/espeak-ng/"

# Adjust includes so the framework can locate headers without additional search paths
perl -pi -e 's|#include <espeak-ng/speak_lib.h>|#include "speak_lib.h"|' \
    "$MACOS_FRAMEWORK_DIR/Versions/A/Headers/espeak_ng.h"
perl -pi -e 's|#include <espeak-ng/speak_lib.h>|#include "speak_lib.h"|' \
    "$MACOS_FRAMEWORK_DIR/Versions/A/Headers/espeak-ng/espeak_ng.h"

# Create umbrella header
cat > "$MACOS_FRAMEWORK_DIR/Versions/A/Headers/ESpeakNG.h" << 'EOF'
#import <ESpeakNG/espeak_ng.h>
#import <ESpeakNG/speak_lib.h>
#import <ESpeakNG/encoding.h>
#import <ESpeakNG/espeak-ng/espeak_ng.h>
#import <ESpeakNG/espeak-ng/speak_lib.h>
#import <ESpeakNG/espeak-ng/encoding.h>
EOF

# Create module map
cat > "$MACOS_FRAMEWORK_DIR/Versions/A/Modules/module.modulemap" << 'EOF'
framework module ESpeakNG {
    umbrella header "ESpeakNG.h"
    export *
    module * { export * }
}
EOF

# Create Info.plist for macOS
cat > "$MACOS_FRAMEWORK_DIR/Versions/A/Resources/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$FRAMEWORK_EXECUTABLE</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_IDENTIFIER</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>ESpeakNG</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>MinimumOSVersion</key>
    <string>$MIN_MACOS_VERSION</string>
</dict>
</plist>
EOF

# Copy espeak-ng-data as a bundle
log "Copying espeak-ng-data to macOS framework..."
ESPEAK_DATA_BUNDLE="$MACOS_FRAMEWORK_DIR/Versions/A/Resources/espeak-ng-data.bundle"
INSTALL_DATA_SRC="$BUILD_DIR/install-macos-arm64/share/espeak-ng-data"
if [ ! -d "$INSTALL_DATA_SRC" ]; then
    error "Expected compiled data at $INSTALL_DATA_SRC"
fi
mkdir -p "$ESPEAK_DATA_BUNDLE/espeak-ng-data"
cp -R "$INSTALL_DATA_SRC/"* "$ESPEAK_DATA_BUNDLE/espeak-ng-data/"

cat > "$ESPEAK_DATA_BUNDLE/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_IDENTIFIER.data</string>
    <key>CFBundleName</key>
    <string>espeak-ng-data</string>
</dict>
</plist>
EOF

# Create framework symbolic links
cd "$MACOS_FRAMEWORK_DIR"
ln -sf Versions/Current/$FRAMEWORK_EXECUTABLE "./$FRAMEWORK_EXECUTABLE"
ln -sf Versions/Current/Headers ./Headers
ln -sf Versions/Current/Modules ./Modules
ln -sf Versions/Current/Resources ./Resources
ln -sf A Versions/Current
cd "$SCRIPT_DIR"

verify_macos_framework "$MACOS_FRAMEWORK_DIR"

# Create framework for Mac Catalyst
log "Creating Mac Catalyst framework..."
MACCATALYST_FRAMEWORK_DIR="$BUILD_DIR/mac-catalyst/$FRAMEWORK_NAME.framework"
mkdir -p "$MACCATALYST_FRAMEWORK_DIR/Headers"
mkdir -p "$MACCATALYST_FRAMEWORK_DIR/Modules"

lipo -create \
    "$BUILD_DIR/build-maccatalyst-arm64/libespeak-ng.1.dylib" \
    "$BUILD_DIR/build-maccatalyst-x86_64/libespeak-ng.1.dylib" \
    -output "$MACCATALYST_FRAMEWORK_DIR/$FRAMEWORK_EXECUTABLE"

install_name_tool -id "@rpath/$FRAMEWORK_NAME.framework/$FRAMEWORK_EXECUTABLE" \
    "$MACCATALYST_FRAMEWORK_DIR/$FRAMEWORK_EXECUTABLE"

# Copy headers
cp "$BUILD_DIR/install-maccatalyst-arm64/include/espeak-ng/espeak_ng.h" \
   "$MACCATALYST_FRAMEWORK_DIR/Headers/"
cp "$BUILD_DIR/install-maccatalyst-arm64/include/espeak-ng/speak_lib.h" \
   "$MACCATALYST_FRAMEWORK_DIR/Headers/"
cp "$BUILD_DIR/install-maccatalyst-arm64/include/espeak-ng/encoding.h" \
   "$MACCATALYST_FRAMEWORK_DIR/Headers/"

mkdir -p "$MACCATALYST_FRAMEWORK_DIR/Headers/espeak-ng"
cp "$BUILD_DIR/install-maccatalyst-arm64/include/espeak-ng/"*.h \
   "$MACCATALYST_FRAMEWORK_DIR/Headers/espeak-ng/"

perl -pi -e 's|#include <espeak-ng/speak_lib.h>|#include "speak_lib.h"|' \
    "$MACCATALYST_FRAMEWORK_DIR/Headers/espeak_ng.h"
perl -pi -e 's|#include <espeak-ng/speak_lib.h>|#include "speak_lib.h"|' \
    "$MACCATALYST_FRAMEWORK_DIR/Headers/espeak-ng/espeak_ng.h"

cat > "$MACCATALYST_FRAMEWORK_DIR/Headers/ESpeakNG.h" << 'EOF'
#import <ESpeakNG/espeak_ng.h>
#import <ESpeakNG/speak_lib.h>
#import <ESpeakNG/encoding.h>
#import <ESpeakNG/espeak-ng/espeak_ng.h>
#import <ESpeakNG/espeak-ng/speak_lib.h>
#import <ESpeakNG/espeak-ng/encoding.h>
EOF

cat > "$MACCATALYST_FRAMEWORK_DIR/Modules/module.modulemap" << 'EOF'
framework module ESpeakNG {
    umbrella header "ESpeakNG.h"
    export *
    module * { export * }
}
EOF

cat > "$MACCATALYST_FRAMEWORK_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$FRAMEWORK_EXECUTABLE</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_IDENTIFIER</string>
    <key>CFBundleName</key>
    <string>ESpeakNG</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>MinimumOSVersion</key>
    <string>$MIN_MAC_CATALYST_VERSION</string>
</dict>
</plist>
EOF

log "Copying espeak-ng-data to Mac Catalyst framework..."
MACCATALYST_ESPEAK_DATA_BUNDLE="$MACCATALYST_FRAMEWORK_DIR/espeak-ng-data.bundle"
mkdir -p "$MACCATALYST_ESPEAK_DATA_BUNDLE/espeak-ng-data"
cp -R "$INSTALL_DATA_SRC/"* "$MACCATALYST_ESPEAK_DATA_BUNDLE/espeak-ng-data/"

cat > "$MACCATALYST_ESPEAK_DATA_BUNDLE/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_IDENTIFIER.data</string>
    <key>CFBundleName</key>
    <string>espeak-ng-data</string>
</dict>
</plist>
EOF

verify_ios_framework "$MACCATALYST_FRAMEWORK_DIR"

# Create framework for iOS device
log "Creating iOS device framework..."
IOS_FRAMEWORK_DIR="$BUILD_DIR/ios/$FRAMEWORK_NAME.framework"
mkdir -p "$IOS_FRAMEWORK_DIR/Headers"
mkdir -p "$IOS_FRAMEWORK_DIR/Modules"

cp "$BUILD_DIR/build-ios-arm64/libespeak-ng.1.dylib" \
   "$IOS_FRAMEWORK_DIR/$FRAMEWORK_EXECUTABLE"

install_name_tool -id "@rpath/$FRAMEWORK_NAME.framework/$FRAMEWORK_EXECUTABLE" \
    "$IOS_FRAMEWORK_DIR/$FRAMEWORK_EXECUTABLE"


# Copy headers
cp "$BUILD_DIR/install-ios-arm64/include/espeak-ng/espeak_ng.h" \
   "$IOS_FRAMEWORK_DIR/Headers/"
cp "$BUILD_DIR/install-ios-arm64/include/espeak-ng/speak_lib.h" \
   "$IOS_FRAMEWORK_DIR/Headers/"
cp "$BUILD_DIR/install-ios-arm64/include/espeak-ng/encoding.h" \
   "$IOS_FRAMEWORK_DIR/Headers/"

mkdir -p "$IOS_FRAMEWORK_DIR/Headers/espeak-ng"
cp "$BUILD_DIR/install-ios-arm64/include/espeak-ng/"*.h \
   "$IOS_FRAMEWORK_DIR/Headers/espeak-ng/"

perl -pi -e 's|#include <espeak-ng/speak_lib.h>|#include "speak_lib.h"|' \
    "$IOS_FRAMEWORK_DIR/Headers/espeak_ng.h"
perl -pi -e 's|#include <espeak-ng/speak_lib.h>|#include "speak_lib.h"|' \
    "$IOS_FRAMEWORK_DIR/Headers/espeak-ng/espeak_ng.h"

cat > "$IOS_FRAMEWORK_DIR/Headers/ESpeakNG.h" << 'EOF'
#import <ESpeakNG/espeak_ng.h>
#import <ESpeakNG/speak_lib.h>
#import <ESpeakNG/encoding.h>
#import <ESpeakNG/espeak-ng/espeak_ng.h>
#import <ESpeakNG/espeak-ng/speak_lib.h>
#import <ESpeakNG/espeak-ng/encoding.h>
EOF

cat > "$IOS_FRAMEWORK_DIR/Modules/module.modulemap" << 'EOF'
framework module ESpeakNG {
    umbrella header "ESpeakNG.h"
    export *
    module * { export * }
}
EOF

# Create Info.plist for iOS
cat > "$IOS_FRAMEWORK_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$FRAMEWORK_EXECUTABLE</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_IDENTIFIER</string>
    <key>CFBundleName</key>
    <string>ESpeakNG</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>MinimumOSVersion</key>
    <string>$MIN_IOS_VERSION</string>
</dict>
</plist>
EOF

# Copy espeak-ng-data bundle to iOS framework
log "Copying espeak-ng-data to iOS framework..."
IOS_ESPEAK_DATA_BUNDLE="$IOS_FRAMEWORK_DIR/espeak-ng-data.bundle"
mkdir -p "$IOS_ESPEAK_DATA_BUNDLE/espeak-ng-data"
cp -R "$INSTALL_DATA_SRC/"* "$IOS_ESPEAK_DATA_BUNDLE/espeak-ng-data/"

cat > "$IOS_ESPEAK_DATA_BUNDLE/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_IDENTIFIER.data</string>
    <key>CFBundleName</key>
    <string>espeak-ng-data</string>
</dict>
</plist>
EOF

verify_ios_framework "$IOS_FRAMEWORK_DIR"

# Create framework for iOS Simulator
log "Creating iOS Simulator framework..."
IOS_SIM_FRAMEWORK_DIR="$BUILD_DIR/ios-simulator/$FRAMEWORK_NAME.framework"
mkdir -p "$IOS_SIM_FRAMEWORK_DIR/Headers"
mkdir -p "$IOS_SIM_FRAMEWORK_DIR/Modules"

lipo -create \
    "$BUILD_DIR/build-iossimulator-arm64/libespeak-ng.1.dylib" \
    "$BUILD_DIR/build-iossimulator-x86_64/libespeak-ng.1.dylib" \
    -output "$IOS_SIM_FRAMEWORK_DIR/$FRAMEWORK_EXECUTABLE"

install_name_tool -id "@rpath/$FRAMEWORK_NAME.framework/$FRAMEWORK_EXECUTABLE" \
    "$IOS_SIM_FRAMEWORK_DIR/$FRAMEWORK_EXECUTABLE"


# Copy headers
cp "$BUILD_DIR/install-iossimulator-arm64/include/espeak-ng/espeak_ng.h" \
   "$IOS_SIM_FRAMEWORK_DIR/Headers/"
cp "$BUILD_DIR/install-iossimulator-arm64/include/espeak-ng/speak_lib.h" \
   "$IOS_SIM_FRAMEWORK_DIR/Headers/"
cp "$BUILD_DIR/install-iossimulator-arm64/include/espeak-ng/encoding.h" \
   "$IOS_SIM_FRAMEWORK_DIR/Headers/"

mkdir -p "$IOS_SIM_FRAMEWORK_DIR/Headers/espeak-ng"
cp "$BUILD_DIR/install-iossimulator-arm64/include/espeak-ng/"*.h \
   "$IOS_SIM_FRAMEWORK_DIR/Headers/espeak-ng/"

perl -pi -e 's|#include <espeak-ng/speak_lib.h>|#include "speak_lib.h"|' \
    "$IOS_SIM_FRAMEWORK_DIR/Headers/espeak_ng.h"
perl -pi -e 's|#include <espeak-ng/speak_lib.h>|#include "speak_lib.h"|' \
    "$IOS_SIM_FRAMEWORK_DIR/Headers/espeak-ng/espeak_ng.h"

cat > "$IOS_SIM_FRAMEWORK_DIR/Headers/ESpeakNG.h" << 'EOF'
#import <ESpeakNG/espeak_ng.h>
#import <ESpeakNG/speak_lib.h>
#import <ESpeakNG/encoding.h>
#import <ESpeakNG/espeak-ng/espeak_ng.h>
#import <ESpeakNG/espeak-ng/speak_lib.h>
#import <ESpeakNG/espeak-ng/encoding.h>
EOF

cat > "$IOS_SIM_FRAMEWORK_DIR/Modules/module.modulemap" << 'EOF'
framework module ESpeakNG {
    umbrella header "ESpeakNG.h"
    export *
    module * { export * }
}
EOF

cat > "$IOS_SIM_FRAMEWORK_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$FRAMEWORK_EXECUTABLE</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_IDENTIFIER</string>
    <key>CFBundleName</key>
    <string>ESpeakNG</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>MinimumOSVersion</key>
    <string>$MIN_IOS_VERSION</string>
</dict>
</plist>
EOF

# Copy espeak-ng-data bundle to iOS Simulator framework
log "Copying espeak-ng-data to iOS Simulator framework..."
IOS_SIM_ESPEAK_DATA_BUNDLE="$IOS_SIM_FRAMEWORK_DIR/espeak-ng-data.bundle"
mkdir -p "$IOS_SIM_ESPEAK_DATA_BUNDLE/espeak-ng-data"
cp -R "$INSTALL_DATA_SRC/"* "$IOS_SIM_ESPEAK_DATA_BUNDLE/espeak-ng-data/"

cat > "$IOS_SIM_ESPEAK_DATA_BUNDLE/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_IDENTIFIER.data</string>
    <key>CFBundleName</key>
    <string>espeak-ng-data</string>
</dict>
</plist>
EOF

verify_ios_framework "$IOS_SIM_FRAMEWORK_DIR"

# Sort Info.plist AvailableLibraries by LibraryIdentifier
sort_xcframework_plist() {
    local plist_path="$1"

    python3 << PYTHON_SORT
import plistlib

plist_path = "$plist_path"

with open(plist_path, 'rb') as f:
    plist = plistlib.load(f)

# Sort AvailableLibraries by LibraryIdentifier
if 'AvailableLibraries' in plist:
    plist['AvailableLibraries'] = sorted(
        plist['AvailableLibraries'],
        key=lambda x: x.get('LibraryIdentifier', '')
    )

with open(plist_path, 'wb') as f:
    plistlib.dump(plist, f, sort_keys=True)
PYTHON_SORT
}

# Create xcframework
log "Creating xcframework..."
XCFRAMEWORK_PATH="$BUILD_DIR/$XCFRAMEWORK_NAME"
rm -rf "$XCFRAMEWORK_PATH"

xcodebuild -create-xcframework \
    -framework "$MACOS_FRAMEWORK_DIR" \
    -framework "$MACCATALYST_FRAMEWORK_DIR" \
    -framework "$IOS_FRAMEWORK_DIR" \
    -framework "$IOS_SIM_FRAMEWORK_DIR" \
    -output "$XCFRAMEWORK_PATH"

# Sort the Info.plist for consistent diffs
log "Sorting Info.plist..."
sort_xcframework_plist "$XCFRAMEWORK_PATH/Info.plist"

# Verify the xcframework
log "Verifying xcframework..."
if [ -d "$XCFRAMEWORK_PATH" ]; then
    log "Successfully created xcframework at: $XCFRAMEWORK_PATH"

    SIZE=$(du -sh "$XCFRAMEWORK_PATH" | cut -f1)
    log "XCFramework size: $SIZE"

    log "Platforms:"
    log "  - macOS (arm64 + x86_64)"
    lipo -info "$MACOS_FRAMEWORK_DIR/Versions/A/$FRAMEWORK_EXECUTABLE"
    log "  - Mac Catalyst (arm64 + x86_64)"
    lipo -info "$MACCATALYST_FRAMEWORK_DIR/$FRAMEWORK_EXECUTABLE"
    log "  - iOS device (arm64)"
    lipo -info "$IOS_FRAMEWORK_DIR/$FRAMEWORK_EXECUTABLE"
    log "  - iOS Simulator (arm64 + x86_64)"
    lipo -info "$IOS_SIM_FRAMEWORK_DIR/$FRAMEWORK_EXECUTABLE"

    log ""
    log "Build complete!"
    log "XCFramework location: $XCFRAMEWORK_PATH"
    log ""
    log "To install in FluidAudio, run:"
    log "  rm -rf ../FluidAudio/Sources/FluidAudio/Frameworks/$XCFRAMEWORK_NAME"
    log "  cp -R $XCFRAMEWORK_PATH ../FluidAudio/Sources/FluidAudio/Frameworks/"
else
    error "Failed to create xcframework"
fi
