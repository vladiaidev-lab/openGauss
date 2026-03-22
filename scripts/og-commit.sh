#!/usr/bin/env bash
# og-commit.sh — Commit and push server changes
# Usage: ./og-commit.sh "commit message"
set -euo pipefail
MSG="${1:-wip}"
cd /opt/software/openGauss/server
sudo -u omm git add -A
sudo -u omm git commit -m "$MSG"
sudo -u omm git push myfork my-changes
