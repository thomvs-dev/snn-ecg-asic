#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
# Frozen official toolchain used for this demonstration.
IMAGE=${ORFS_IMAGE:-openroad/orfs@sha256:dd46c586ac071475bd54f32d6bc52bb6bba463304e133b3dbf0d49e825a79174}
mkdir -p reports physical
docker image inspect "$IMAGE" --format '{{json .RepoDigests}}' > reports/orfs_image_digest.json
docker run --rm -v "$ROOT:/work" "$IMAGE" bash -lc 'source /OpenROAD-flow-scripts/env.sh; openroad -version; yosys -V; klayout -v; git -C /OpenROAD-flow-scripts rev-parse HEAD || echo "Container omits git metadata; reproduce by image digest."' > reports/container_versions.txt 2>&1
docker run --rm -v "$ROOT:/work" -w /OpenROAD-flow-scripts/flow "$IMAGE" bash -lc 'source /OpenROAD-flow-scripts/env.sh; make DESIGN_CONFIG=/work/flow/config.mk WORK_HOME=/work/physical' 2>&1 | tee reports/physical_flow.log
