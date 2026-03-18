#!/usr/bin/env bash
# og-start.sh — Start or restart the openGauss server (source-built debug version)
# Usage: ./og-start.sh          # start
#        ./og-start.sh restart  # restart
set -euo pipefail

MODE="${1:-start}"

# Clean stale PID if starting fresh
if [ "$MODE" = "start" ]; then
  sudo -u omm rm -f /opt/software/openGauss/data/postmaster.pid 2>/dev/null || true
fi

sudo -u omm bash -c "
  export GAUSSHOME=/opt/software/openGauss/server/mppdb_temp_install
  export LD_LIBRARY_PATH=\$GAUSSHOME/lib:/usr/lib/x86_64-linux-gnu:\${LD_LIBRARY_PATH:-}
  export PATH=\$GAUSSHOME/bin:\$PATH
  export LANG=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
  gs_ctl $MODE -D /opt/software/openGauss/data -Z single_node
"
echo ""
echo "=== Server ${MODE}ed ==="

# Quick version check
sudo -u omm bash -c '
  export GAUSSHOME=/opt/software/openGauss/server/mppdb_temp_install
  export LD_LIBRARY_PATH=$GAUSSHOME/lib:/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}
  export PATH=$GAUSSHOME/bin:$PATH
  gsql -d postgres -c "SELECT version();" 2>/dev/null
' || true
