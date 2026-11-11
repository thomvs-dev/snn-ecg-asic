#!/usr/bin/env bash
set -euo pipefail
# Tested host: Ubuntu 26.04 under WSL2. Run as root (sudo bash ...).
apt-get update
apt-get install -y iverilog yosys python3 docker.io klayout
systemctl start docker
docker pull openroad/orfs@sha256:dd46c586ac071475bd54f32d6bc52bb6bba463304e133b3dbf0d49e825a79174
iverilog -V
yosys -V
klayout -v
