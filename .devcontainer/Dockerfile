FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
        build-essential \
        cmake make \
        flex bison \
        patch \
        git git-lfs \
        python3 \
        tar bzip2 wget curl \
        libaio-dev \
        libncurses-dev \
        libreadline-dev \
        unixodbc unixodbc-dev \
        sudo \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash vscode \
    && echo "vscode ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN groupadd -f dbgrp \
    && useradd -g dbgrp -m -s /bin/bash omm \
    && echo "omm ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN mkdir -p /opt/software/openGauss/data \
    && chown -R omm:dbgrp /opt/software/openGauss
    
