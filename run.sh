#!/bin/bash
# Build Rams, then install and launch it on an iPad simulator.
#   ./run.sh                 open the app as it starts
#   ./run.sh fs-split        open it straight on a named demo moment
set -e
cd "$(dirname "$0")" || exit 1

./build.sh

# Prefer an iPad Pro, then any iPad, then whatever is already booted.
DEVICE=$(xcrun simctl list devices available \
  | grep -oE 'iPad Pro 13-inch [^(]*' | head -1 | sed 's/ *$//')
[ -z "$DEVICE" ] && DEVICE=$(xcrun simctl list devices available \
  | grep -oE 'iPad [^(]*' | head -1 | sed 's/ *$//')

if [ -z "$DEVICE" ]; then
  echo "No iPad simulator found. Install one in Xcode: Settings > Components."
  exit 1
fi

echo "Using $DEVICE"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator
sleep 4

APP=.build/Build/Products/Debug-iphonesimulator/Rams.app
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl terminate "$DEVICE" com.oolio.rams 2>/dev/null || true

if [ -n "$1" ]; then
  xcrun simctl launch "$DEVICE" com.oolio.rams --demo "$1"
else
  xcrun simctl launch "$DEVICE" com.oolio.rams
fi

echo
echo "Rotate the Simulator to landscape with Command and the left arrow."
