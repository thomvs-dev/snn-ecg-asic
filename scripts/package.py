"""Package source and evidence; exclude installed tools, Git data and the IEEE paper.

Creates deliverables/ecg_snn_sky130_demo.zip, a per-file SHA-256 manifest,
checks every ZIP CRC, checks required contents are present and forbidden
content is absent, and writes the archive hash.
"""
from pathlib import Path
import hashlib, json, zipfile

root = Path(__file__).resolve().parents[1]
out = root / 'deliverables'
out.mkdir(exist_ok=True)
BASE = 'physical/results/sky130hd/ecg_snn_core/base'

files = [root / n for n in ['README.md', 'LICENSE', 'TASKS.md', 'toolchain.json']]
for folder in ['rtl', 'rtl_cg', 'tb', 'scripts', 'flow', 'flow_cg', 'flow_cg2', 'flow_cg3', 'rtl_cg3', 'docs', 'vendor/HDL-SpikingNet-ECG',
               'reports', 'physical/logs', 'physical/reports']:
    for p in (root / folder).rglob('*'):
        if not p.is_file() or '.git' in p.parts or '__pycache__' in p.parts:
            continue
        if p.name.startswith('paper') or p.name in ['orfs_readme.md', 'openroad_release.json']:
            continue  # IEEE paper extracts; upstream tool documentation
        if p.name.endswith('.~backup') or p.suffix.lower() == '.pdf':
            continue
        if 'poster' in p.name.lower() or p.name.startswith('chip_art_preview'):
            continue  # posters hold paper figures and sponsor logos; previews superseded by chip_art_cg2.png
        if p.parent.name.startswith('power_') and p.suffix == '.vcd':
            continue  # 4 x 4-118 MB final-netlist traces; regenerate with activity_power_variant.sh
        files.append(p)
finals = [root / BASE] + [d for d in [root / BASE.replace('/base', v) for v in ('/cg', '/cg2', '/cg3')] if (d / '6_final.gds').exists()]
for p in [q for d in finals for q in d.glob('*')]:
    # Final outputs only; 6_1_* are intermediate copies of the final ODB/GDS.
    if p.is_file() and ((p.name.startswith('6_') and not p.name.startswith('6_1_'))
                        or p.name in ['1_2_yosys.v', '1_synth.sdc', 'ecg_snn_core_extracted.cir']):
        files.append(p)
for name in ['ecg_snn_core_generic.v', 'sky130hd_sim.v']:
    files.append(root / 'build' / name)
files = sorted(set(files))
rel = [str(p.relative_to(root)).replace('\\', '/') for p in files]

REQUIRED = [
    'README.md', 'LICENSE', 'toolchain.json', 'docs/DEMO.md', 'docs/RTL_AUDIT.md',
    'docs/architecture.png', 'docs/THIRD_PARTY.md', 'reports/RESULTS.md', 'reports/final_summary.json',
    'rtl/ecg_snn_core.v', 'flow/config.mk', 'flow/constraint.sdc',
    'vendor/HDL-SpikingNet-ECG/LICENSE', 'vendor/HDL-SpikingNet-ECG/hex_files/input_data.hex',
    'tb/tb_core.sv', 'tb/tb_protocol.sv', 'tb/tb_idle.sv',
    'scripts/verify.sh', 'scripts/verify_mapped.sh', 'scripts/verify_final.sh',
    'scripts/activity_power.sh', 'scripts/run_physical.sh', 'docs/CLOCK_GATING.md', 'rtl_cg/clock_gate.v', 'reports/cg/comparison.md', 'reports/power_cg/idle.json', 'reports/power_base/idle.json', 'reports/layout_full_readable_cg.png', 'scripts/physical_checks.sh',
    'reports/cg2/comparison.md', 'reports/cg2/chip_art.txt', 'reports/chip_art_cg2.png', 'reports/layout_full_readable_cg2.png',
    'scripts/chip_art.py', 'scripts/chip_art_render.py', 'scripts/run_cg2.sh', 'flow_cg2/config.mk',
    'physical/results/sky130hd/ecg_snn_core/cg2/6_final.gds', 'physical/reports/sky130hd/ecg_snn_core/cg2/6_drc_count.rpt',
    'rtl_cg3/ecg_snn_core.v', 'flow_cg3/config.mk', 'flow_cg3/constraint.sdc', 'scripts/run_cg3.sh', 'scripts/verify_cg3.sh',
    'tb/tb_root_gate.sv', 'tb/tb_random.sv', 'reports/cg3/comparison.md', 'reports/cg3/chip_art.txt',
    'reports/cg3/rtl_random.log', 'reports/cg3/rtl_root_gate.log', 'reports/cg3/final_gate_simulation.log',
    'reports/cg3/final_gate_random.log', 'reports/cg3/drc_mr.lyrdb', 'reports/cg3/sta_tt_025C_1v80.rpt',
    'reports/cg3/sta_ff_n40C_1v95.rpt', 'reports/cg3/sta_ss_100C_1v60.rpt', 'reports/power_cg3/idle.json',
    'reports/chip_art_cg3.png', 'reports/layout_full_readable_cg3.png',
    'physical/results/sky130hd/ecg_snn_core/cg3/6_final.gds', 'physical/reports/sky130hd/ecg_snn_core/cg3/6_drc_count.rpt',
    'reports/baseline.csv', 'reports/final_gate_simulation.log', 'reports/final_gate_protocol.log',
    'reports/power_activity.json', 'reports/power_idle.json', 'reports/mapped_activity.vcd',
    'reports/idle_activity.vcd', 'reports/layout_full_readable.png', 'reports/layout_closeup_readable.png',
    f'{BASE}/6_final.gds', f'{BASE}/6_final.def', f'{BASE}/6_final.odb', f'{BASE}/6_final.v',
    f'{BASE}/6_final.sdc', f'{BASE}/6_final.spef', f'{BASE}/6_lvs.lvsdb', f'{BASE}/6_final.cdl',
    f'{BASE}/ecg_snn_core_extracted.cir',
    'physical/logs/sky130hd/ecg_snn_core/base/6_report.json',
    'physical/reports/sky130hd/ecg_snn_core/base/6_finish.rpt',
    'physical/reports/sky130hd/ecg_snn_core/base/6_drc_count.rpt',
    'physical/logs/sky130hd/ecg_snn_core/base/6_lvs.log',
]
missing = [r for r in REQUIRED if r not in rel]
assert not missing, f'missing required files: {missing}'
forbidden = [r for r in rel if r.startswith(('tools/', 'deliverables/', '_to_delete/'))
             or r.lower().endswith('.pdf') or '/paper' in r or r.startswith('paper') or 'poster' in r.lower()]
assert not forbidden, f'forbidden content: {forbidden}'

manifest = {r: hashlib.sha256(p.read_bytes()).hexdigest() for r, p in zip(rel, files)}
(out / 'SHA256SUMS.json').write_text(json.dumps(manifest, indent=2) + '\n')
archive = out / 'ecg_snn_sky130_demo.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for r, p in zip(rel, files):
        z.write(p, r)
    z.write(out / 'SHA256SUMS.json', 'SHA256SUMS.json')
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    names = set(z.namelist())
    assert set(rel) <= names
    for r in REQUIRED:  # content round trip for required files
        assert hashlib.sha256(z.read(r)).hexdigest() == manifest[r], r
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
(out / 'archive_sha256.txt').write_text(digest + '  ' + archive.name + '\n')
size = sum(p.stat().st_size for p in files)
print(f'{archive}: {archive.stat().st_size} bytes ({size} uncompressed), {len(files)} files; '
      f'ZIP CRC passed; {len(REQUIRED)} required files present and hash-verified; sha256 {digest}')
