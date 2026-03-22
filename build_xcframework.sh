#!/bin/bash

# MDEditor XCFramework Build Script
# This script bundles MDEditor into a binary XCFramework.

set -e

FRAMEWORK_NAME="MDEditor"
OUTPUT_DIR="./build"
XCFRAMEWORK_PATH="${OUTPUT_DIR}/${FRAMEWORK_NAME}.xcframework"

# 1. Generate Xcode Project
echo "Generating Xcode project using xcodegen..."
if ! command -v xcodegen &> /dev/null; then
    echo "xcodegen not found, please install it (brew install xcodegen)"
    exit 1
fi
xcodegen generate

# 2. Clean previous builds
echo "Cleaning old builds..."
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

# 3. Archive for macOS
echo "Archiving for macOS..."
xcodebuild archive \
    -project "${FRAMEWORK_NAME}.xcodeproj" \
    -scheme "${FRAMEWORK_NAME}" \
    -destination "generic/platform=macOS" \
    -archivePath "${OUTPUT_DIR}/macOS.xcarchive" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# 4. Create XCFramework
echo "Creating XCFramework..."
xcodebuild -create-xcframework \
    -framework "${OUTPUT_DIR}/macOS.xcarchive/Products/Library/Frameworks/${FRAMEWORK_NAME}.framework" \
    -output "${XCFRAMEWORK_PATH}"

echo "Successfully created XCFramework at: ${XCFRAMEWORK_PATH}"
