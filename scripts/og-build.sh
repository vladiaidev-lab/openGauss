#!/usr/bin/env bash
# og-build.sh — Incremental build (recompiles only changed files)
set -euo pipefail

sudo -u omm bash -c '
  export LANG=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
  export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64
  cd /opt/software/openGauss/server
  bash build.sh -m debug -3rd /opt/software/openGauss/binarylibs
'
echo ""
echo "=== Build complete ==="
