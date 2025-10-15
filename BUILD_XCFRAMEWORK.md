# Building ESpeakNG.xcframework for iOS and macOS

This document describes how to build an xcframework for eSpeak NG that supports both iOS and macOS (arm64 only) for use in Swift projects.

## Prerequisites

- macOS 14.0 or later
- Xcode Command Line Tools
- autoconf, automake, libtool (install via Homebrew if needed)

```bash
brew install autoconf automake libtool
```

## Build Instructions

1. **Run the build script:**

```bash
./build_xcframework.sh
```

This will:
- Configure and build espeak-ng for both arm64 and x86_64 architectures
- Create a universal binary combining both architectures
- Package the framework with proper headers and module map
- Include the espeak-ng-data bundle
- Create the final ESpeakNG.xcframework

2. **Find the output:**

The xcframework will be located at:
```
build/ESpeakNG.xcframework
```

## Installing in FluidAudio

To replace the existing framework in FluidAudio:

```bash
rm -rf ../FluidAudio/Sources/FluidAudio/Frameworks/ESpeakNG.xcframework
cp -R build/ESpeakNG.xcframework ../FluidAudio/Sources/FluidAudio/Frameworks/
```

## Framework Structure

The xcframework includes three platforms:

### macOS (arm64)
- Minimum deployment target: macOS 14.0
- Framework structure with versioned layout
- Data bundle at: `Versions/A/Resources/espeak-ng-data.bundle`

### iOS Device (arm64)
- Minimum deployment target: iOS 16.0
- Flat framework structure
- Data bundle at: `espeak-ng-data.bundle`

### iOS Simulator (arm64)
- Minimum deployment target: iOS 16.0
- Flat framework structure
- Data bundle at: `espeak-ng-data.bundle`

### Headers (all platforms):
- `espeak_ng.h` - Main eSpeak NG API
- `speak_lib.h` - Legacy eSpeak API
- `encoding.h` - Text encoding support
- `ESpeakNG.h` - Umbrella header

### Data Bundle (all platforms):
- `espeak-ng-data.bundle/espeak-ng-data/` - Contains all language data and voices
- Includes `lang/`, `voices/`, and `mbrola_ph/` directories

## Build Configuration

The framework is built with only the features needed for phoneme conversion:
- Klatt formant synthesizer: **disabled** (not used - FluidAudio only needs G2P)
- MBROLA support: **disabled** (not used)
- SpeechPlayer: **disabled** (not used)
- Async support: **disabled** (not used)
- PCAudioLib: **disabled** (no audio output needed)
- Sonic: **disabled** (no audio processing needed)

**Note:** FluidAudio only uses eSpeak NG for grapheme-to-phoneme (G2P) conversion via `espeak_TextToPhonemes()`. The speech synthesis features are not needed.

## Troubleshooting

### Missing autotools

If you see errors about `configure` not found or autotools, install them:

```bash
brew install autoconf automake libtool
```

### Build fails with architecture errors

Make sure you're on macOS with Apple Silicon or Intel. The script builds for both architectures by default.

### Data bundle missing

The script copies `espeak-ng-data/` from the source repository. Make sure this directory exists and contains the voice data.

## Notes

- The framework uses a bundle identifier of `com.kokoro.espeakng`
- The data bundle is embedded in each framework variant
- The library is set up to be used with `@rpath` for flexible linking
- Only arm64 architecture is built (Apple Silicon native)
- The build process:
  1. Builds macOS framework first (needed to compile phoneme/dictionary data)
  2. Builds iOS frameworks reusing the compiled data from step 1
  3. Combines all three frameworks into a single xcframework

## Platform Support

- macOS 14.0+ (arm64)
- iOS 16.0+ (arm64 device and simulator)

## License

eSpeak NG is distributed under the GNU GPL v3 or later. See the `COPYING` file in the repository root.
