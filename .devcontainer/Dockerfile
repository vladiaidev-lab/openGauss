FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
        build-essential cmake make flex bison patch \
        git git-lfs python3 \
        tar bzip2 wget curl lz4 \
        libaio-dev libncurses-dev libreadline-dev \
        unixodbc unixodbc-dev \
        iproute2 locales \
        libcjson-dev liblz4-dev libxml2-dev libxslt1-dev \
        libkrb5-dev libssl-dev zlib1g-dev libedit-dev \
        lsb-release \
        openjdk-8-jdk-headless \
        libcgroup1 \
        sudo \
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen en_US.UTF-8

# Node.js for Claude Code runtime
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Symlinks for CentOS 7 binary compatibility
RUN ln -s /usr/lib/x86_64-linux-gnu/libncurses.so.6 /usr/lib/x86_64-linux-gnu/libncurses.so.5 \
    && ln -s /usr/lib/x86_64-linux-gnu/libtinfo.so.6 /usr/lib/x86_64-linux-gnu/libtinfo.so.5 \
    && ln -s /usr/lib/x86_64-linux-gnu/libreadline.so.8 /usr/lib/x86_64-linux-gnu/libreadline.so.6 \
    && ln -s /usr/lib/x86_64-linux-gnu/libedit.so.2 /usr/lib/x86_64-linux-gnu/libedit.so.0

# CRT object files and libraries for bundled GCC cross-compilation
RUN mkdir -p /usr/lib64 \
    && for f in /usr/lib/x86_64-linux-gnu/*.o; do ln -sf "$f" /usr/lib64/$(basename "$f") 2>/dev/null; done \
    && for f in /usr/lib/x86_64-linux-gnu/*.so; do ln -sf "$f" /usr/lib64/$(basename "$f") 2>/dev/null; done

# Arch-specific headers accessible to bundled GCC (searches /usr/include/sys/ not /usr/include/x86_64-linux-gnu/sys/)
RUN mkdir -p /usr/include/sys \
    && for f in /usr/include/x86_64-linux-gnu/sys/*.h; do \
         base=$(basename "$f"); \
         [ ! -e "/usr/include/sys/$base" ] && ln -sf "$f" "/usr/include/sys/$base"; \
       done \
    && for d in asm bits gnu; do \
         [ ! -e "/usr/include/$d" ] && ln -sf "/usr/include/x86_64-linux-gnu/$d" "/usr/include/$d"; \
       done

# libssl1.1 (openGauss links against it; Ubuntu 22.04 ships OpenSSL 3.x)
RUN wget -q http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb \
    && dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb \
    && rm libssl1.1_1.1.1f-1ubuntu2_amd64.deb

# Stub headers removed from modern glibc (must come AFTER sys symlinks so we override socket.h etc.)
RUN printf '#ifndef _SYS_SYSCTL_H\n#define _SYS_SYSCTL_H\n#include <linux/sysctl.h>\n#endif\n' > /usr/include/sys/sysctl.h \
    && printf '#ifndef _SYS_VTIMES_H\n#define _SYS_VTIMES_H\n#include <sys/resource.h>\nstruct vtimes { int vm_utime; int vm_stime; int vm_idsrss; int vm_ixrss; int vm_maxrss; int vm_pagein; int vm_majflt; int vm_minflt; int vm_nswap; int vm_inblk; int vm_oublk; };\n#endif\n' > /usr/include/sys/vtimes.h

# JNI headers accessible globally
RUN ln -sf /usr/lib/jvm/java-8-openjdk-amd64/include/jni.h /usr/include/jni.h \
    && ln -sf /usr/lib/jvm/java-8-openjdk-amd64/include/linux/jni_md.h /usr/include/jni_md.h

# Create vscode user for Codespaces
RUN useradd -m -s /bin/bash vscode \
    && echo "vscode ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create omm user (database owner)
RUN groupadd -f dbgrp \
    && useradd -g dbgrp -m -s /bin/bash omm \
    && echo "omm ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Prepare installation directory
RUN mkdir -p /opt/software/openGauss/data \
    && chown -R omm:dbgrp /opt/software/openGauss

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64