#!/bin/zsh
# App Store screenshots (6.9", 1320x2868) from the booted iPhone Pro Max simulator.
# Debug launch flags fake the time and spot (-now, -place, -rules); the status bar is
# overridden to match. Output: tools/shots/store/NN-name.png
set -e
SIM=${SIM:-booted}
BID=dev.ducktyping.shootinghours
OUT=${0:A:h}/shots/store; mkdir -p $OUT
APP=${0:A:h}/../DerivedData-sim/Build/Products/Debug-iphonesimulator/ShootingHours.app
xcrun simctl install $SIM $APP
xcrun simctl spawn $SIM defaults write $BID seenDisclaimer -bool YES
shot() { # name time layer args...
  local name=$1 t=$2 layer=$3; shift 3
  xcrun simctl spawn $SIM defaults write $BID map.layer $layer
  xcrun simctl status_bar $SIM override --time "$t" --batteryState charged --batteryLevel 100 \
    --cellularMode active --cellularBars 3 --wifiBars 0 --dataNetwork lte
  xcrun simctl terminate $SIM $BID 2>/dev/null || true
  xcrun simctl launch $SIM $BID -store -layer $layer "$@" >/dev/null
  sleep 4
  xcrun simctl io $SIM screenshot $OUT/$name.png >/dev/null 2>&1
  echo "  $name"
}
# deer opener, 24 minutes before legal light at Stevens Point (zone C, opens 6:31)
shot 01-deer-opener 6:07 hours -place "Stevens Point" -rules smallgame -now 2026-11-21T06:07:18-06:00
# ducks at Horicon, legal, the duck-zone map
shot 02-duck-map 7:42 duck -place Horicon -rules waterfowl -now 2026-11-07T07:42:05-06:00 -scroll daybar
# hours zones map from the far west (zone F)
shot 03-hours-map 6:58 hours -place Hudson -rules waterfowl -now 2026-10-24T06:58:40-05:00 -scroll daybar
# the week ahead, deer season
shot 04-week 12:30 hours -place "Stevens Point" -rules smallgame -now 2026-11-21T12:30:00-06:00 -scroll week
# icons
shot 05-icons 12:30 hours -place "Stevens Point" -rules smallgame -settings
xcrun simctl status_bar $SIM clear
