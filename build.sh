#!/bin/bash
# Build Rams for the iOS Simulator and show only what went wrong.
# Device-agnostic, so it works on any Mac with Xcode 26 regardless of which
# simulators happen to be installed.
set -o pipefail
cd "$(dirname "$0")" || exit 1
xcodebuild -project Rams.xcodeproj -scheme Rams \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  -derivedDataPath .build \
  build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | sort -u | head -40
