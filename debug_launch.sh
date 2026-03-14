#!/bin/bash
# Stop any running instances first
pkill -f LogitechPreciseVolumeRollerForMac || true
sleep 1

# Run the binary directly from the built .app
echo "🚀 Starting app manually to capture output..."
./LogitechPreciseVolumeRoller.app/Contents/MacOS/LogitechPreciseVolumeRollerForMac
