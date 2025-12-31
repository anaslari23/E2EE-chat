#!/bin/bash

# Define SSD Cache Paths
export PUB_CACHE="/Volumes/SSD/pub_cache"
export GRADLE_USER_HOME="/Volumes/SSD/.gradle_cache"
export CP_HOME_DIR="/Volumes/SSD/.cocoapods_cache"
export XDG_CACHE_HOME="/Volumes/SSD/.cache" # Generic cache

# Print Configuration
echo "🚀 Configuring Build Environment for SSD storage..."
echo "------------------------------------------------"
echo "📦 PUB_CACHE:        $PUB_CACHE"
echo "🐘 GRADLE_HOME:      $GRADLE_USER_HOME"
echo "🍎 COCOAPODS_HOME:   $CP_HOME_DIR"
echo "------------------------------------------------"

# Ensure directories exist
mkdir -p "$PUB_CACHE" "$GRADLE_USER_HOME" "$CP_HOME_DIR"

# Run Command (Default to flutter run if no args)
if [ $# -eq 0 ]; then
    echo "▶️  Running: flutter run"
    flutter run
else
    echo "▶️  Running: $@"
    "$@"
fi
