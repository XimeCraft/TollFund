#!/bin/bash

# TollFund App Data Cleaner
# This script cleans all app data to resolve Core Data migration issues

echo "🧹 TollFund App Data Cleaner"
echo "================================"

# iOS Simulator paths
SIM_PATH="$HOME/Library/Developer/CoreSimulator/Devices"
APP_BUNDLE_ID="com.yourcompany.TollFund"  # Replace with actual bundle ID

echo "🔍 Searching for TollFund app data..."

# Find and remove app data from all simulators
find "$SIM_PATH" -name "*$APP_BUNDLE_ID*" -type d 2>/dev/null | while read -r dir; do
    if [ -d "$dir" ]; then
        echo "🗑️  Removing: $dir"
        rm -rf "$dir"
    fi
done

# Clean derived data
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
echo "🧽 Cleaning Xcode Derived Data..."
find "$DERIVED_DATA" -name "*TollFund*" -type d 2>/dev/null | while read -r dir; do
    if [ -d "$dir" ]; then
        echo "🗑️  Removing: $dir"
        rm -rf "$dir"
    fi
done

echo "✅ App data cleanup completed!"
echo ""
echo "📱 Next steps:"
echo "1. Clean build in Xcode (Cmd+Shift+K)"
echo "2. Reset iOS Simulator (Device > Erase All Content and Settings)"
echo "3. Build and run the app"
echo ""
