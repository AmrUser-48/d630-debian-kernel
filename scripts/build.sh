#!/bin/bash
# build.sh — deterministic, reproducible
set -e
make tinyconfig
source ./enable-features.sh   # your scripts/config lines
make olddefconfig
make -j$(nproc)   
