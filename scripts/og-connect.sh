#!/usr/bin/env bash
# og-connect.sh — Open interactive gsql session to openGauss
# Usage: ./og-connect.sh                    # connect to postgres db
#        ./og-connect.sh mydb               # connect to specific db
#        ./og-connect.sh postgres "SELECT 1" # run a single command
set -euo pipefail

DB="${1:-postgres}"
CMD="${2:-}"

if [ -n "$CMD" ]; then
  # Run single command
  sudo -u omm bash -c "
    export GAUSSHOME=/opt/software/openGauss/server/mppdb_temp_install
    export LD_LIBRARY_PATH=\$GAUSSHOME/lib:/usr/lib/x86_64-linux-gnu:\${LD_LIBRARY_PATH:-}
    export PATH=\$GAUSSHOME/bin:\$PATH
    gsql -d $DB -c \"$CMD\"
  "
else
  # Interactive session
  echo "Connecting to openGauss database '$DB'..."
  echo "Type \\q to quit, \\h for help"
  echo ""
  sudo -u omm bash -c "
    export GAUSSHOME=/opt/software/openGauss/server/mppdb_temp_install
    export LD_LIBRARY_PATH=\$GAUSSHOME/lib:/usr/lib/x86_64-linux-gnu:\${LD_LIBRARY_PATH:-}
    export PATH=\$GAUSSHOME/bin:\$PATH
    gsql -d $DB
  "
fi
