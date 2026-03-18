# openGauss 7.0.0-RC2 — Codespaces Recovery & Setup Guide

> **Purpose**: Rebuild the full development environment from scratch if the Codespace is lost.
> Everything below was field-tested on GitHub Codespaces (Ubuntu 22.04) on 2026-03-18.

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
gcc --version       # should show Ubuntu's GCC 11.x
lsb_release -a      # Ubuntu 22.04
ls /usr/include/sys/sysctl.h   # stub header should exist
ls /usr/lib64/crt1.o           # symlink should exist
```

---

## Step 2: Open the Multi-Root Workspace

```bash
code openGauss.code-workspace
```

VS Code will reload. You'll need to re-add the server folder after Step 3.

---

## Step 3: Clone the openGauss Source (~2 min)

```bash
sudo -u omm bash -c '
  cd /opt/software/openGauss
  git lfs install
  git clone https://gitcode.com/opengauss/openGauss-server.git server
  cd server
  git checkout 7.0.0-RC2
'
```

### Apply the source patches for Ubuntu compatibility

Two files need modification to compile on Ubuntu:

```bash
# 1. Fix gettimeofday ambiguity in commproxy_interface.h
sudo -u omm sed -i 's|^extern int gettimeofday(struct timeval\* tp, struct timezone\* tzp);|// removed for Ubuntu: extern int gettimeofday(struct timeval* tp, struct timezone* tzp);|' \
  /opt/software/openGauss/server/src/include/communication/commproxy_interface.h

# 2. Fix gettimeofday in instr_time.h
sudo -u omm sed -i 's|gettimeofday(&(t), NULL)|gettimeofday(\&(t), (struct timezone *)NULL)|' \
  /opt/software/openGauss/server/src/include/portability/instr_time.h
```

### Verify patches

```bash
grep "removed for Ubuntu" /opt/software/openGauss/server/src/include/communication/commproxy_interface.h
grep "struct timezone" /opt/software/openGauss/server/src/include/portability/instr_time.h
```

### Add server to workspace

```bash
code -a /opt/software/openGauss/server
```

---

## Step 4: Download the Precompiled Third-Party Libraries (~5 min)

```bash
sudo -u omm bash -c '
  cd /opt/software/openGauss
  wget https://opengauss.obs.cn-south-1.myhuaweicloud.com/latest/binarylibs/gcc10.3/openGauss-third_party_binarylibs_Centos7.6_x86_64.tar.gz
  tar -xzf openGauss-third_party_binarylibs_Centos7.6_x86_64.tar.gz
  mv openGauss-third_party_binarylibs_Centos7.6_x86_64 binarylibs
'
```

---

## Step 5: First Build (~25-30 min)

```bash
sudo -u omm bash -c '
  export LANG=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
  export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64
  cd /opt/software/openGauss/server
  bash build.sh -m debug -3rd /opt/software/openGauss/binarylibs
' 2>&1 | tee /tmp/build.log
```

### Verify build succeeded

```bash
ls -l /opt/software/openGauss/server/mppdb_temp_install/bin/gaussdb && echo "BUILD SUCCESS"
```

---

## Step 6: Download the Pre-built Server (for the data directory) (~1 min)

You need a pre-built server to run `install.sh` which creates the initial data directory with `gs_initdb`. This is faster than using your debug build for initialization.

```bash
sudo -u omm bash -c '
  cd /opt/software/openGauss
  wget https://download.opengauss.org/archive_test/7.0.0-RC2/openGauss7.0.0-RC2.B028/CentOS7/x86/openGauss-Lite-7.0.0-RC2-CentOS7-x86_64.tar.gz
  mkdir -p install
  tar -xzf openGauss-Lite-7.0.0-RC2-CentOS7-x86_64.tar.gz -C install
'
```

### Run the installer to create the data directory

```bash
sudo -u omm bash -c '
  export LANG=en_US.UTF-8
  export LC_ALL=en_US.UTF-8
  export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
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
- The auto-start may fail (that's OK — we'll use our source build)

---

## Step 7: Configure TCP Access

```bash
sudo -u omm bash -c '
  export GAUSSHOME=/opt/software/openGauss/app
  export LD_LIBRARY_PATH=$GAUSSHOME/lib:/opt/software/openGauss/install/dependency:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
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

## Step 8: Start the Source-Built Server

```bash
sudo -u omm bash -c '
  rm -f /opt/software/openGauss/data/postmaster.pid
  export GAUSSHOME=/opt/software/openGauss/server/mppdb_temp_install
  export LD_LIBRARY_PATH=$GAUSSHOME/lib:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
  export PATH=$GAUSSHOME/bin:$PATH
  export LANG=en_US.UTF-8
  gs_ctl start -D /opt/software/openGauss/data -Z single_node
'
```

### Verify it's your debug build

```bash
sudo -u omm bash -c '
  export GAUSSHOME=/opt/software/openGauss/server/mppdb_temp_install
  export LD_LIBRARY_PATH=$GAUSSHOME/lib:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
  export PATH=$GAUSSHOME/bin:$PATH
  gsql -d postgres -c "SELECT version();"
'
```

Expected: `... debug on x86_64-unknown-linux-gnu ...`

---

## Step 9: Set Up ODBC (for C++ testing)

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

## Step 10: Test C++ Program

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

## Estimated Recovery Time

| Step | Time |
|---|---|
| Codespace creation (Dockerfile build, cached) | ~2 min |
| Clone source + checkout tag | ~2 min |
| Apply source patches | ~1 min |
| Download binarylibs (1.5 GB) | ~5 min |
| Extract binarylibs | ~3 min |
| First full build | ~25-30 min |
| Download Lite + init data | ~2 min |
| Configure + start server | ~1 min |
| Download ODBC + configure | ~1 min |
| **Total** | **~45-50 min** |
