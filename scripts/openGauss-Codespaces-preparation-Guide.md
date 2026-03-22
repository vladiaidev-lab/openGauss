# openGauss 7.0.0-RC2 — Codespaces Recovery & Setup Guide

> **Purpose**: Rebuild the full development environment from scratch if the Codespace is lost.
> Field-tested on GitHub Codespaces (Ubuntu 22.04) on 2026-03-18 and 2026-03-22.

---

## Prerequisites

Your GitHub repo (`openGauss`) must already contain these committed files:
- `.devcontainer/Dockerfile` — with all Ubuntu compatibility fixes baked in
- `.devcontainer/devcontainer.json`
- `scripts/og-*.sh` — dev workflow scripts

If those are committed, a new Codespace will boot with all system packages, symlinks, and stub headers pre-installed. You only need to re-download the openGauss source and binaries.

---

## Step 1: Create a New Codespace

From your repo on GitHub, click **Code → Codespaces → Create codespace on main**.

Wait for the Dockerfile to build (~5-10 minutes on first build, cached after that).

Once the terminal opens, verify the environment:

```bash
gcc --version                    # should show Ubuntu's GCC 11.x
lsb_release -a                   # Ubuntu 22.04
ls /usr/include/sys/sysctl.h     # stub header should exist
ls /usr/include/sys/socket.h     # arch symlink should exist
ls /usr/lib64/crt1.o             # CRT symlink should exist
node --version                   # Node.js for Claude Code
```

---

## Step 2: Install and Authenticate Claude Code

```bash
curl -fsSL https://claude.ai/install.sh | bash
claude
```

When `/login` shows a URL, open it in your regular browser. Before clicking Authorize, go to the **Ports** tab in VS Code (bottom panel) and set all ports to **Public**. Then complete the authorization in the browser.

---

## Step 3: Open the Multi-Root Workspace

```bash
code openGauss.code-workspace
```

VS Code will reload. You'll need to re-add the server folder after Step 4.

---

## Step 4: Clone the openGauss Source (~2 min)

### Option A: Clone from your private fork (recommended — patches already applied)
```bash
sudo -u omm bash -c '
  cd /opt/software/openGauss
  git lfs install
  git clone -b my-changes https://github.com/vladiaidev-lab/openGauss-server.git server
'
```

### Option B: Clone from upstream (if fork is unavailable)
```bash
sudo -u omm bash -c '
  cd /opt/software/openGauss
  git lfs install
  git clone https://gitcode.com/opengauss/openGauss-server.git server
  cd server
  git checkout 7.0.0-RC2
'
```

Then apply the source patches for Ubuntu compatibility:
```bash
# 1. Fix gettimeofday ambiguity in commproxy_interface.h
sudo -u omm sed -i 's|^extern int gettimeofday(struct timeval\* tp, struct timezone\* tzp);|// removed for Ubuntu: extern int gettimeofday(struct timeval* tp, struct timezone* tzp);|' \
  /opt/software/openGauss/server/src/include/communication/commproxy_interface.h

# 2. Fix gettimeofday in instr_time.h
sudo -u omm sed -i 's|gettimeofday(&(t), NULL)|gettimeofday(\&(t), (struct timezone *)NULL)|' \
  /opt/software/openGauss/server/src/include/portability/instr_time.h
```

### After cloning (either option), add the fork remote and add to workspace
```bash
cd /opt/software/openGauss/server
sudo -u omm git remote add myfork https://github.com/vladiaidev-lab/openGauss-server.git
code -a /opt/software/openGauss/server
```

---

## Step 5: Download the Precompiled Third-Party Libraries (~5 min)

You can start this in a second terminal while Step 4 is still cloning.

```bash
sudo -u omm bash -c '
  cd /opt/software/openGauss
  wget https://opengauss.obs.cn-south-1.myhuaweicloud.com/latest/binarylibs/gcc10.3/openGauss-third_party_binarylibs_Centos7.6_x86_64.tar.gz
  tar -xzf openGauss-third_party_binarylibs_Centos7.6_x86_64.tar.gz
  mv openGauss-third_party_binarylibs_Centos7.6_x86_64 binarylibs
'
```

### Verify extraction

```bash
du -sh /opt/software/openGauss/binarylibs && echo "DONE"
```

---

## Step 6: First Build (~25-30 min)

```bash
sudo -u omm bash -c '
  export LANG=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
  export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64
  cd /opt/software/openGauss/server
  bash build.sh -m debug -3rd /opt/software/openGauss/binarylibs
' 2>&1 | tee /tmp/build.log
```

### Monitor build progress (in another terminal)

```bash
pgrep cc1plus | wc -l
```

### Verify build succeeded

```bash
ls -l /opt/software/openGauss/server/mppdb_temp_install/bin/gaussdb && echo "BUILD SUCCESS"
```

> **Note**: Warnings about `libog_query.so` and `SPQ_ROOT` at the end are harmless plugin messages, not build failures.

---

## Step 7: Download the Pre-built Server and Initialize Data Directory (~2 min)

You need the pre-built server to run `gs_initdb` which creates the initial data directory.

```bash
sudo -u omm bash -c '
  cd /opt/software/openGauss
  wget https://download.opengauss.org/archive_test/7.0.0-RC2/openGauss7.0.0-RC2.B028/CentOS7/x86/openGauss-Lite-7.0.0-RC2-CentOS7-x86_64.tar.gz
  mkdir -p install
  tar -xzf openGauss-Lite-7.0.0-RC2-CentOS7-x86_64.tar.gz -C install
'
```

### Copy dependency libraries to standard paths

The pre-built binaries need libraries in `/usr/lib64/`:

```bash
sudo cp /opt/software/openGauss/install/dependency/* /usr/lib64/ 2>/dev/null
sudo ldconfig
```

### Run the installer to create the data directory

```bash
sudo -u omm bash -c '
  export LANG=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
  export LD_LIBRARY_PATH=/usr/lib64:/opt/software/openGauss/app/lib:/opt/software/openGauss/install/dependency:/usr/lib/x86_64-linux-gnu
  cd /opt/software/openGauss/install
  bash install.sh \
    -D /opt/software/openGauss/data \
    -R /opt/software/openGauss/app \
    -P "-w Dev@12345"
'
```

This will:
- Decompress binaries to `/opt/software/openGauss/app`
- Run `gs_initdb` to create the data cluster at `/opt/software/openGauss/data`
- The `gs_guc` config tuning at the end may fail — that's OK, we configure manually next

### Copy app libraries to standard paths (for gs_guc and other tools)

```bash
sudo cp /opt/software/openGauss/app/lib/lib*.so* /usr/lib64/ 2>/dev/null
sudo ldconfig
```

---

## Step 8: Configure TCP Access

```bash
sudo -u omm bash -c '
  export GAUSSHOME=/opt/software/openGauss/app
  export LD_LIBRARY_PATH=$GAUSSHOME/lib:/opt/software/openGauss/install/dependency:/usr/lib64:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
  export PATH=$GAUSSHOME/bin:$PATH

  gs_guc set -D /opt/software/openGauss/data -c "listen_addresses = '\''*'\''"
  gs_guc set -D /opt/software/openGauss/data -c "password_encryption_type = 1"

  cat >> /opt/software/openGauss/data/pg_hba.conf <<EOF
host  all  all  127.0.0.1/32  sha256
host  all  all  ::1/128       sha256
EOF
'
```

---

## Step 9: Start the Source-Built Server

```bash
sudo -u omm bash -c '
  rm -f /opt/software/openGauss/data/postmaster.pid
  export GAUSSHOME=/opt/software/openGauss/server/mppdb_temp_install
  export LD_LIBRARY_PATH=$GAUSSHOME/lib:/usr/lib64:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
  export PATH=$GAUSSHOME/bin:$PATH
  export LANG=en_US.UTF-8
  gs_ctl start -D /opt/software/openGauss/data -Z single_node
'
```

### Verify it's your debug build

```bash
sudo -u omm bash -c '
  export GAUSSHOME=/opt/software/openGauss/server/mppdb_temp_install
  export LD_LIBRARY_PATH=$GAUSSHOME/lib:/usr/lib64:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
  export PATH=$GAUSSHOME/bin:$PATH
  gsql -d postgres -c "SELECT version();"
'
```

Expected: `... compiled at 2026-xx-xx ... debug on x86_64-unknown-linux-gnu ...`

---

## Step 10: Set Up ODBC (for C++ testing)

### Download the ODBC driver

```bash
sudo -u omm bash -c '
  cd /opt/software/openGauss
  wget https://download.opengauss.org/archive_test/7.0.0-RC2/openGauss7.0.0-RC2.B028/CentOS7/x86/openGauss-ODBC-7.0.0-RC2-CentOS7-x86_64.tar.gz
  mkdir -p odbc
  tar -xzf openGauss-ODBC-7.0.0-RC2-CentOS7-x86_64.tar.gz -C odbc
'
```

### Register driver and DSN

```bash
sudo tee /etc/odbcinst.ini > /dev/null <<'EOF'
[GaussMPP]
Description = openGauss ODBC Driver (Unicode)
Driver      = /opt/software/openGauss/odbc/odbc/lib/psqlodbcw.so
Setup       = /opt/software/openGauss/odbc/odbc/lib/psqlodbcw.so
EOF

sudo tee /etc/odbc.ini > /dev/null <<'EOF'
[openGaussDev]
Driver      = GaussMPP
Servername  = 127.0.0.1
Database    = postgres
Username    = omm
Port        = 5432
Sslmode     = disable
EOF
```

### Test ODBC

```bash
export LD_LIBRARY_PATH=/opt/software/openGauss/odbc/lib:/opt/software/openGauss/app/lib:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
export ODBCINI=/etc/odbc.ini
export ODBCSYSINI=/etc
isql -v openGaussDev omm "Dev@12345"
```

---

## Step 11: Test C++ Program

```bash
cd /workspaces/openGauss
g++ -std=c++17 -Wall -I/usr/include main.cpp -L/usr/lib/x86_64-linux-gnu -lodbc -o test_opengauss

export LD_LIBRARY_PATH=/opt/software/openGauss/odbc/lib:/opt/software/openGauss/app/lib:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
export ODBCINI=/etc/odbc.ini
export ODBCSYSINI=/etc
./test_opengauss
```

Expected:
```
Connected to openGauss!
Server version: (openGauss 7.0.0-RC2 build ...) ... debug ...
```

---

## Step 12: Copy CLAUDE.md to Server Source

```bash
sudo cp /workspaces/openGauss/CLAUDE.md /opt/software/openGauss/server/CLAUDE.md
sudo chown omm:dbgrp /opt/software/openGauss/server/CLAUDE.md
```

---

## Quick Reference: Download URLs

| Package | URL | Size |
|---|---|---|
| Binarylibs (build deps) | `https://opengauss.obs.cn-south-1.myhuaweicloud.com/latest/binarylibs/gcc10.3/openGauss-third_party_binarylibs_Centos7.6_x86_64.tar.gz` | ~1.5 GB |
| Lite Server (for gs_initdb) | `https://download.opengauss.org/archive_test/7.0.0-RC2/openGauss7.0.0-RC2.B028/CentOS7/x86/openGauss-Lite-7.0.0-RC2-CentOS7-x86_64.tar.gz` | ~40 MB |
| ODBC Driver | `https://download.opengauss.org/archive_test/7.0.0-RC2/openGauss7.0.0-RC2.B028/CentOS7/x86/openGauss-ODBC-7.0.0-RC2-CentOS7-x86_64.tar.gz` | ~10 MB |

## Quick Reference: Key Paths

| Item | Path |
|---|---|
| Your workspace / repo | `/workspaces/openGauss/` |
| Dev scripts | `/workspaces/openGauss/scripts/` |
| Server source code | `/opt/software/openGauss/server/src/` |
| Kernel source | `/opt/software/openGauss/server/src/gausskernel/` |
| Source-built binaries | `/opt/software/openGauss/server/mppdb_temp_install/bin/` |
| Pre-built app binaries | `/opt/software/openGauss/app/bin/` |
| Binarylibs (3rd party) | `/opt/software/openGauss/binarylibs/` |
| ODBC driver | `/opt/software/openGauss/odbc/odbc/lib/psqlodbcw.so` |
| Data directory | `/opt/software/openGauss/data/` |
| Database password | `Dev@12345` |

## Quick Reference: Daily Dev Workflow

```bash
# Edit source code in /opt/software/openGauss/server/src/
cd /workspaces/openGauss

# Incremental build (~2-5 min)
./scripts/og-build.sh

# Restart server with new binary
./scripts/og-start.sh restart

# Test
./scripts/og-connect.sh postgres "SELECT version();"

# Or interactive SQL
./scripts/og-connect.sh
```

## Estimated Recovery Time

| Step | Time |
|---|---|
| Codespace creation (Dockerfile build, cached) | ~2 min |
| Claude Code install + login | ~2 min |
| Clone source + checkout tag | ~2 min |
| Apply source patches | ~1 min |
| Download binarylibs (1.5 GB) | ~5 min |
| Extract binarylibs | ~3 min |
| First full build | ~25-30 min |
| Download Lite + init data + copy libs | ~3 min |
| Configure + start server | ~1 min |
| Download ODBC + configure | ~1 min |
| **Total** | **~45-50 min** |

## Troubleshooting

### Build fails with "sys/socket.h: No such file or directory"
The Dockerfile should handle this, but if needed manually:
```bash
sudo bash -c 'for f in /usr/include/x86_64-linux-gnu/sys/*.h; do
  base=$(basename "$f")
  [ ! -e "/usr/include/sys/$base" ] && ln -sf "$f" "/usr/include/sys/$base"
done'
sudo bash -c 'for d in asm bits gnu; do
  [ ! -e "/usr/include/$d" ] && ln -sf "/usr/include/x86_64-linux-gnu/$d" "/usr/include/$d"
done'
```

### gs_initdb fails with "libcgroup.so.2: cannot open"
```bash
sudo cp /opt/software/openGauss/install/dependency/* /usr/lib64/ 2>/dev/null
sudo ldconfig
```

### Claude Code says "Not logged in"
Ensure Node.js is installed (`node --version`). If missing:
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt-get install -y nodejs
```
Then run `claude` and complete the OAuth login with ports set to Public.

### Build fails with "gettimeofday ambiguous"
Source patches from Step 4 were not applied. Re-run the `sed` commands.

### Server won't start — "postmaster.pid already exists"
```bash
sudo -u omm rm -f /opt/software/openGauss/data/postmaster.pid
```