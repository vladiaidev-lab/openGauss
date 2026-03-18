#!/usr/bin/env bash
# og-build-clean.sh — Full clean build from scratch (~25-30 min)
set -euo pipefail

echo "=== Cleaning previous build artifacts ==="
sudo -u omm bash -c '
  cd /opt/software/openGauss/server
  make distclean 2>/dev/null || true
'

echo "=== Starting full build ==="
sudo -u omm bash -c '
  export LANG=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
  export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64
  cd /opt/software/openGauss/server
  bash build.sh -m debug -3rd /opt/software/openGauss/binarylibs
'
echo ""
echo "=== Full build complete ==="
