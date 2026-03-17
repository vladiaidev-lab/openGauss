#!/usr/bin/env bash
set -euo pipefail

if sudo sysctl -w kernel.sem="250 85000 250 330" 2>/dev/null; then
  echo "==> kernel.sem tuned successfully"
else
  echo "==> WARNING: Could not set kernel.sem (may cause gs_initdb to fail)"
fi

chown -R omm:dbgrp /opt/software/openGauss
