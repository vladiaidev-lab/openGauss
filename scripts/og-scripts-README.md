# openGauss Dev Scripts

Quick-reference scripts for the edit → build → restart → test cycle.

## Setup

Copy scripts to your workspace and make executable:
```bash
cp /path/to/og-*.sh /workspaces/openGauss/scripts/
chmod +x /workspaces/openGauss/scripts/og-*.sh
```

## Usage

| Script | Purpose | Time |
|---|---|---|
| `./og-build.sh` | Incremental build (changed files only) | 1-5 min |
| `./og-build-clean.sh` | Full clean build from scratch | 25-30 min |
| `./og-stop.sh` | Stop the server | instant |
| `./og-start.sh` | Start the server | ~3 sec |
| `./og-start.sh restart` | Restart the server | ~3 sec |
| `./og-connect.sh` | Interactive gsql session | — |
| `./og-connect.sh postgres "SELECT 1"` | Run single SQL command | — |

## Typical Workflow

```bash
# 1. Edit source code
code /opt/software/openGauss/server/src/gausskernel/

# 2. Build (incremental)
./scripts/og-build.sh

# 3. Restart server with new binary
./scripts/og-start.sh restart

# 4. Test
./scripts/og-connect.sh postgres "SELECT version();"

# Or open interactive session
./scripts/og-connect.sh
```

## Key Paths

| Item | Path |
|---|---|
| Server source code | `/opt/software/openGauss/server/src/` |
| Kernel source | `/opt/software/openGauss/server/src/gausskernel/` |
| Compiled binaries | `/opt/software/openGauss/server/mppdb_temp_install/bin/` |
| Data directory | `/opt/software/openGauss/data/` |
| Build log | `/tmp/build.log` |
