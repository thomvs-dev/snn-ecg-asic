#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
IMAGE=${ORFS_IMAGE:-openroad/orfs@sha256:dd46c586ac071475bd54f32d6bc52bb6bba463304e133b3dbf0d49e825a79174}
docker run --rm -v "$ROOT:/work" -w /OpenROAD-flow-scripts/flow "$IMAGE" bash -lc 'source /OpenROAD-flow-scripts/env.sh; make DESIGN_CONFIG=/work/flow/config.mk WORK_HOME=/work/physical drc' 2>&1 | tee reports/drc_driver.log
docker run --rm -v "$ROOT:/work" -w /OpenROAD-flow-scripts/flow "$IMAGE" bash -lc 'source /OpenROAD-flow-scripts/env.sh; make DESIGN_CONFIG=/work/flow/config.mk WORK_HOME=/work/physical lvs' 2>&1 | tee reports/lvs_driver.log
