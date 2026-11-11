#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
exec 9>build/inspection.lock
flock 9
STAMP=$(sha256sum physical/results/sky130hd/ecg_snn_core/base/6_final.gds reports/mapped_activity.vcd reports/idle_activity.vcd scripts/power.tcl scripts/layout_images.py | sha256sum | cut -d' ' -f1)
if [[ -f reports/inspection.sha256 && "$(cat reports/inspection.sha256)" == "$STAMP" ]]; then
 echo 'Layout and activity inputs unchanged; inspection outputs already exist.'
 exit 0
fi
IMAGE=${ORFS_IMAGE:-openroad/orfs@sha256:dd46c586ac071475bd54f32d6bc52bb6bba463304e133b3dbf0d49e825a79174}
docker run --rm -e QT_QPA_PLATFORM=offscreen -v "$(pwd):/work" "$IMAGE" klayout -z -r /work/scripts/layout_images.py 2>&1 | tee reports/klayout_inspection.log
docker run --rm -v "$(pwd):/work" "$IMAGE" bash -lc 'source /OpenROAD-flow-scripts/env.sh; openroad -exit /work/scripts/power.tcl' 2>&1 | tee reports/power_estimation.log
echo "$STAMP" > reports/inspection.sha256
