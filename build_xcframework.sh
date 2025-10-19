#!/bin/bash
set -e

# Build script for ESpeakNG.xcframework with iOS and macOS support (arm64 only)

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_DIR="$SCRIPT_DIR/build"
FRAMEWORK_NAME="ESpeakNG"
BUNDLE_IDENTIFIER="com.kokoro.espeakng"
VERSION="1.52.0"
MIN_MACOS_VERSION="14.0"
MIN_IOS_VERSION="17.0"

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

    local CONFIG_ENV=(
        "SDKROOT=$SDK_PATH"
        "CFLAGS=$COMMON_CFLAGS"
        "CXXFLAGS=$COMMON_CFLAGS"
        "LDFLAGS=$COMMON_LDFLAGS"
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
    env "${BUILD_ENV[@]}" make -j$(sysctl -n hw.ncpu)

    # Install
    log "Installing for $PLATFORM $ARCH..."
    env "${BUILD_ENV[@]}" make install

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

    local CONFIG_ENV=(
        "SDKROOT=$SDK_PATH"
        "CFLAGS=$COMMON_CFLAGS"
        "CXXFLAGS=$COMMON_CFLAGS"
        "LDFLAGS=$COMMON_LDFLAGS"
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
    env "${BUILD_ENV[@]}" make install-exec install-espeak_includeHEADERS install-espeak_ng_includeHEADERS

    # Copy just the library
    mkdir -p "$BUILD_SUBDIR"
    cp "$INSTALL_DIR/lib/libespeak-ng.1.dylib" "$BUILD_SUBDIR/"

    make distclean 2>/dev/null || true
}

build_ios_platform "ios" "arm64" "iphoneos" "$MIN_IOS_VERSION"
build_ios_platform "iossimulator" "arm64" "iphonesimulator" "$MIN_IOS_VERSION"

# Create framework for macOS
log "Creating macOS framework..."
MACOS_FRAMEWORK_DIR="$BUILD_DIR/macos/ESpeakNG.framework"
mkdir -p "$MACOS_FRAMEWORK_DIR/Versions/A/Headers"
mkdir -p "$MACOS_FRAMEWORK_DIR/Versions/A/Modules"
mkdir -p "$MACOS_FRAMEWORK_DIR/Versions/A/Resources"

cp "$BUILD_DIR/build-macos-arm64/libespeak-ng.1.dylib" \
   "$MACOS_FRAMEWORK_DIR/Versions/A/ESpeakNG"

install_name_tool -id "@rpath/ESpeakNG.framework/Versions/A/ESpeakNG" \
    "$MACOS_FRAMEWORK_DIR/Versions/A/ESpeakNG"

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
    <string>ESpeakNG</string>
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
ln -sf Versions/A/ESpeakNG ./ESpeakNG
ln -sf Versions/A/Headers ./Headers
ln -sf Versions/A/Modules ./Modules
ln -sf Versions/A/Resources ./Resources
ln -sf A Versions/Current
cd "$SCRIPT_DIR"

# Create framework for iOS device
log "Creating iOS device framework..."
IOS_FRAMEWORK_DIR="$BUILD_DIR/ios/ESpeakNG.framework"
mkdir -p "$IOS_FRAMEWORK_DIR/Headers"
mkdir -p "$IOS_FRAMEWORK_DIR/Modules"

cp "$BUILD_DIR/build-ios-arm64/libespeak-ng.1.dylib" \
   "$IOS_FRAMEWORK_DIR/ESpeakNG"

install_name_tool -id "@rpath/ESpeakNG.framework/ESpeakNG" \
    "$IOS_FRAMEWORK_DIR/ESpeakNG"

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
    <string>ESpeakNG</string>
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

# Create framework for iOS Simulator
log "Creating iOS Simulator framework..."
IOS_SIM_FRAMEWORK_DIR="$BUILD_DIR/ios-simulator/ESpeakNG.framework"
mkdir -p "$IOS_SIM_FRAMEWORK_DIR/Headers"
mkdir -p "$IOS_SIM_FRAMEWORK_DIR/Modules"

cp "$BUILD_DIR/build-iossimulator-arm64/libespeak-ng.1.dylib" \
   "$IOS_SIM_FRAMEWORK_DIR/ESpeakNG"

install_name_tool -id "@rpath/ESpeakNG.framework/ESpeakNG" \
    "$IOS_SIM_FRAMEWORK_DIR/ESpeakNG"

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
    <string>ESpeakNG</string>
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

# Create xcframework
log "Creating xcframework..."
XCFRAMEWORK_PATH="$BUILD_DIR/ESpeakNG.xcframework"
rm -rf "$XCFRAMEWORK_PATH"

xcodebuild -create-xcframework \
    -framework "$MACOS_FRAMEWORK_DIR" \
    -framework "$IOS_FRAMEWORK_DIR" \
    -framework "$IOS_SIM_FRAMEWORK_DIR" \
    -output "$XCFRAMEWORK_PATH"

# Verify the xcframework
log "Verifying xcframework..."
if [ -d "$XCFRAMEWORK_PATH" ]; then
    log "Successfully created xcframework at: $XCFRAMEWORK_PATH"

    SIZE=$(du -sh "$XCFRAMEWORK_PATH" | cut -f1)
    log "XCFramework size: $SIZE"

    log "Platforms:"
    log "  - macOS (arm64)"
    lipo -info "$MACOS_FRAMEWORK_DIR/Versions/A/ESpeakNG"
    log "  - iOS device (arm64)"
    file "$IOS_FRAMEWORK_DIR/ESpeakNG"
    log "  - iOS Simulator (arm64)"
    file "$IOS_SIM_FRAMEWORK_DIR/ESpeakNG"

    log ""
    log "Build complete!"
    log "XCFramework location: $XCFRAMEWORK_PATH"
    log ""
    log "To install in FluidAudio, run:"
    log "  rm -rf ../FluidAudio/Sources/FluidAudio/Frameworks/ESpeakNG.xcframework"
    log "  cp -R $XCFRAMEWORK_PATH ../FluidAudio/Sources/FluidAudio/Frameworks/"
else
    error "Failed to create xcframework"
fi
