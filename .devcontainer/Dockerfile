# Use the "22.03" shorthand tag — it always points to the latest
# service pack of the 22.03 LTS series and is the tag Docker Hub
# lists as the recommended alias.
FROM openeuler/openeuler:22.03

# ── System dependencies (cached in image layer) ─────────────────────
# Build toolchain (from the openGauss Software Dependency Matrix)
RUN dnf install -y \
        gcc gcc-c++ \
        cmake make \
        flex bison \
        patch \
        git git-lfs \
        python3 \
        tar bzip2 wget \
        libaio-devel \
        ncurses-devel \
        readline-devel \
        unixODBC unixODBC-devel \
        sudo shadow procps-ng \
    && dnf clean all

# ── Create the vscode user for Codespaces ────────────────────────────
# Done explicitly because Microsoft's common-utils feature
# does not reliably work on openEuler.
RUN useradd -m -s /bin/bash vscode \
    && echo "vscode ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ── Create the omm user who will own the database ───────────────────
RUN groupadd -f dbgrp \
    && useradd -g dbgrp -m -s /bin/bash omm \
    && echo "omm ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ── Prepare the installation directory ───────────────────────────────
RUN mkdir -p /opt/software/openGauss/data \
    && chown -R omm:dbgrp /opt/software/openGauss