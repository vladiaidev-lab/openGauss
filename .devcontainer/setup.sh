#!/usr/bin/env bash
set -euo pipefail

# ── Tune kernel semaphores for openGauss ──────────────────────────────
# This MUST be done at runtime, not in runArgs, because Codespaces
# rejects --sysctl flags during container creation.
# --privileged gives us the CAP_SYS_ADMIN needed to write to /proc.
if sysctl -w kernel.sem="250 85000 250 330" 2>/dev/null; then
  echo "==> kernel.sem tuned successfully"
else
  echo "==> WARNING: Could not set kernel.sem (may cause gs_initdb to fail)"
fi

# ── Ensure directory ownership ────────────────────────────────────────
chown -R omm:dbgrp /opt/software/openGauss