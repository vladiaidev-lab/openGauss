# CLAUDE.md — openGauss Kernel Development Guide

## Project Overview
openGauss is an enterprise-class open-source relational database management system, forked from PostgreSQL 9.2.4 with extensive modifications for high concurrency, multi-core optimization, and enterprise features. The codebase is ~2M lines, primarily C and C++.

This is version **7.0.0-RC2** (Lite edition), running on **Ubuntu 22.04 in GitHub Codespaces** with CentOS 7 binarylibs cross-compiled using bundled GCC 10.3.

## Build System

### Quick Commands
```bash
# Incremental build (changed files only, ~2-5 min)
cd /workspaces/openGauss && ./scripts/og-build.sh

# Full clean build (~25-30 min)
cd /workspaces/openGauss && ./scripts/og-build-clean.sh

# Manual build (from server dir)
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64
cd /opt/software/openGauss/server
bash build.sh -m debug -3rd /opt/software/openGauss/binarylibs
```

### Build Details
- **Build tool**: `build.sh` wrapper around `configure` + `make` (NOT CMake for the full kernel)
- **Compiler**: Bundled GCC 10.3 from binarylibs (NOT system GCC)
- **Binarylibs path**: `/opt/software/openGauss/binarylibs`
- **Build output**: `/opt/software/openGauss/server/mppdb_temp_install/`
- **Build mode**: `-m debug` (with symbols) or `-m release` (optimized)
- **Incremental builds work**: `make` tracks dependencies, only recompiles changed files

### Ubuntu-Specific Patches Applied
Two source files are patched for Ubuntu compatibility:
1. `src/include/communication/commproxy_interface.h` — conflicting `gettimeofday` declaration commented out
2. `src/include/portability/instr_time.h` — `gettimeofday` call uses explicit `(struct timezone *)NULL` cast

Do NOT revert these or the build will fail with "ambiguous overload" errors.

## Server Management

```bash
# Stop server
cd /workspaces/openGauss && ./scripts/og-stop.sh

# Start server
cd /workspaces/openGauss && ./scripts/og-start.sh

# Restart server (after rebuild)
cd /workspaces/openGauss && ./scripts/og-start.sh restart

# Interactive SQL session
cd /workspaces/openGauss && ./scripts/og-connect.sh

# Run single SQL command
cd /workspaces/openGauss && ./scripts/og-connect.sh postgres "SELECT version();"
```

### Server Details
- **Data directory**: `/opt/software/openGauss/data/`
- **Port**: 5432
- **Superuser**: `omm` (password: `Dev@12345`)
- **GAUSSHOME**: `/opt/software/openGauss/server/mppdb_temp_install`
- **All server commands must run as user `omm`** (use `sudo -u omm bash -c '...'`)

## Source Code Layout

### Key Directories
```
src/
├── gausskernel/           # Main database kernel
│   ├── bootstrap/         # Database bootstrap (initdb)
│   ├── catalog/           # System catalog management
│   ├── cbb/               # Common building blocks
│   ├── communication/     # Inter-node communication
│   ├── optimizer/         # Query optimizer/planner
│   ├── parser/            # SQL parser
│   ├── process/           # Process management
│   │   ├── postmaster/    # Main server process
│   │   ├── tcop/          # Traffic cop (query dispatch)
│   │   └── threadpool/    # Thread pool management
│   ├── runtime/           # Query executor
│   │   └── executor/      # Execution engine
│   ├── security/          # Authentication, encryption
│   └── storage/           # Storage engine
│       ├── access/        # Access methods (heap, index, WAL)
│       ├── buffer/        # Buffer manager
│       ├── ipc/           # Inter-process communication
│       ├── lmgr/          # Lock manager
│       ├── mot/           # Memory-Optimized Tables (MOT) engine
│       ├── page/          # Page management
│       ├── replication/   # Replication (streaming, logical)
│       └── smgr/          # Storage manager
├── common/
│   ├── backend/           # Common backend code
│   ├── interfaces/
│   │   └── libpq/         # Client library (libpq)
│   └── pl/                # Procedural languages (PL/pgSQL)
├── include/               # All header files
│   ├── access/            # Access method headers
│   ├── catalog/           # System catalog headers
│   ├── commands/          # SQL command headers
│   ├── executor/          # Executor headers
│   ├── knl/               # Kernel session/instance globals
│   ├── nodes/             # Parse/plan node definitions
│   ├── optimizer/         # Optimizer headers
│   ├── parser/            # Parser headers
│   ├── storage/           # Storage headers
│   └── utils/             # Utility headers
├── bin/                   # Client tools (gsql, gs_ctl, etc.)
├── lib/                   # Shared libraries
└── test/                  # Test suites
    └── regress/           # Regression tests (pg_regress style)
```

### Key Files
- `src/gausskernel/process/postmaster/postmaster.cpp` — Main server entry point
- `src/gausskernel/process/tcop/postgres.cpp` — Query processing main loop
- `src/gausskernel/runtime/executor/` — Query execution engine
- `src/gausskernel/optimizer/` — Query planner/optimizer
- `src/gausskernel/storage/access/heap/` — Heap (row store) access methods
- `src/gausskernel/storage/access/transam/` — Transaction management, WAL
- `src/gausskernel/storage/mot/` — Memory-Optimized Tables engine
- `src/include/knl/knl_session.h` — Per-session global state
- `src/include/knl/knl_instance.h` — Per-instance global state

## Coding Conventions

- **Language**: Mostly C++ (`.cpp`), some C (`.c`). Headers are `.h`.
- **Style**: PostgreSQL-derived style. Use tabs for indentation in core code.
- **Memory**: Uses PostgreSQL-style memory contexts (`palloc`/`pfree`), NOT `malloc`/`free`.
- **Error handling**: `ereport(ERROR, ...)` for errors, `elog(LOG, ...)` for logging.
- **Globals**: Session state in `u_sess->...`, instance state in `g_instance->...`, thread state in `t_thrd->...`.
- **String safety**: Uses `securec` functions (`memcpy_s`, `strcpy_s`, etc.) — include `securec.h`.
- **No C++ STL in core**: Core kernel avoids `std::string`, `std::vector`, etc. Uses PostgreSQL `List`, `StringInfo`, etc.

## Testing

### Regression Tests
```bash
# Run full regression suite (from server dir)
cd /opt/software/openGauss/server
make check -C src/test/regress
```

### Adding Tests
- Regression tests live in `src/test/regress/sql/` (input) and `src/test/regress/expected/` (expected output)
- Add new test name to `src/test/regress/parallel_schedule`

## Environment Constraints (Codespaces-Specific)

- **No kernel tuning**: `/proc/sys` is read-only. `sysctl` writes fail. Default semaphore values work for single-node Lite.
- **No `--privileged`**: Not needed for current setup.
- **All database ops as `omm` user**: Never run gaussdb as root or vscode.
- **ODBC driver**: `/opt/software/openGauss/odbc/odbc/lib/psqlodbcw.so`
- **C++ test program**: `/workspaces/openGauss/main.cpp` with `g++ -lodbc`

## Common Pitfalls

1. **Always use `bash` not `sh`** for build scripts — Ubuntu's `sh` is `dash` which lacks `declare`.
2. **Library symlinks**: CentOS 7 binaries expect `.so.5`/`.so.6` versions; Ubuntu has `.so.6`/`.so.8`. Symlinks are created in the Dockerfile.
3. **Build uses bundled GCC 10.3**, not system GCC 11. Don't mix them.
4. **After editing headers in `src/include/`**, many files will recompile. Incremental build may take longer.
5. **`objfiles.txt` warning** during parallel build is harmless — it resolves itself.
