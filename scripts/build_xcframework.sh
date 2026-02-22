#!/bin/bash

# MDEditor XCFramework Build Script
# This script bundles MDEditor into a binary XCFramework.

set -e

FRAMEWORK_NAME="MDEditor"
OUTPUT_DIR="./build"
XCFRAMEWORK_PATH="${OUTPUT_DIR}/${FRAMEWORK_NAME}.xcframework"

# 1. Clean previous builds
echo "Cleaning old builds..."
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

# 2. Archive for macOS
echo "Archiving for macOS..."
xcodebuild archive \
    -workspace . \
    -scheme "${FRAMEWORK_NAME}" \
    -destination "platform=macOS" \
    -archivePath "${OUTPUT_DIR}/macOS.xcarchive" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES

# 3. Create XCFramework
echo "Creating XCFramework..."
xcodebuild -create-xcframework \
    -archive "${OUTPUT_DIR}/macOS.xcarchive" -framework "${FRAMEWORK_NAME}.framework" \
    -output "${XCFRAMEWORK_PATH}"

echo "Successfully created XCFramework at: ${XCFRAMEWORK_PATH}"
