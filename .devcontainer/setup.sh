#!/usr/bin/env bash
set -euo pipefail

echo "==> Post-create: ensuring directory ownership"
chown -R omm:dbgrp /opt/software/openGauss