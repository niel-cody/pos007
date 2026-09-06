#!/bin/bash
# Build Rams for the iPad simulator and show only what went wrong.
set -o pipefail
xcodebuild -project "$(dirname "$0")/Rams.xcodeproj" -scheme Rams \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  -configuration Debug \
  -derivedDataPath "$(dirname "$0")/.build" \
  build 2>&1 | grep -E "error:|warning: unused|BUILD (SUCCEEDED|FAILED)" | sort -u | head -60
