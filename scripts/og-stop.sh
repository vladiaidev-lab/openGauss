#!/usr/bin/env bash
# og-stop.sh — Stop the openGauss server
set -euo pipefail

sudo -u omm bash -c '
  export GAUSSHOME=/opt/software/openGauss/server/mppdb_temp_install
  export LD_LIBRARY_PATH=$GAUSSHOME/lib:/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}
  export PATH=$GAUSSHOME/bin:$PATH
  gs_ctl stop -D /opt/software/openGauss/data -Z single_node
'
echo ""
echo "=== Server stopped ==="
