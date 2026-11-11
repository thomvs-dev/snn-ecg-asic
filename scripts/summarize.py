"""Summarize functional, physical and power evidence from raw logs/reports.

Writes:
  reports/functional_results.json  functional regressions (RTL ... final netlist)
  reports/final_summary.json       all-stage summary used by reports/RESULTS.md
Every value is read from an evidence file; nothing is typed in by hand.
"""
from pathlib import Path
import csv, json, re, statistics

root = Path(__file__).resolve().parents[1]
R = root / 'reports'
P = root / 'physical'
BASE = 'sky130hd/ecg_snn_core/base'
CLK_NS = 40.0


def text(p):
    p = root / p
    return p.read_text(errors='replace') if p.exists() else ''


def pass_line(p, token='PASS'):
    lines = [l for l in text(p).splitlines() if l.startswith(token)]
    return lines[-1] if lines else None


def vcd_end_ps(p):
    p = root / p
    with p.open('rb') as f:
        f.seek(max(0, p.stat().st_size - 4096))
        tail = f.read().decode(errors='replace')
    return int(re.findall(r'^#(\d+)', tail, re.M)[-1])


# ---------------------------------------------------------------- functional
rows = list(csv.DictReader((R / 'baseline.csv').open()))
cycles = [int(r['cycles']) for r in rows]
func = {
    'vectors': len(rows),
    'class_counts': {str(k): sum(int(r['class']) == k for r in rows) for k in range(4)},
    'timeout_count': sum(int(r['no_spike']) for r in rows),
    'cycles': {'min': min(cycles), 'max': max(cycles), 'mean': statistics.mean(cycles)},
    'target_clock_ns': CLK_NS,
    'latency_us': {k: v * CLK_NS / 1000 for k, v in
                   {'min': min(cycles), 'max': max(cycles), 'mean': statistics.mean(cycles)}.items()},
    'accuracy': None, 'f1': None, 'labels_available': False,
}
regressions = {
    'rtl': ('rtl_predictions.csv', 'core_simulation.log', 'protocol.log'),
    'generic_gate': ('generic_gate_predictions.csv', 'generic_gate_simulation.log', 'generic_gate_protocol.log'),
    'mapped_gate': ('mapped_gate_predictions.csv', 'mapped_gate_simulation.log', 'mapped_gate_protocol.log'),
    'final_gate': ('final_gate_predictions.csv', 'final_gate_simulation.log', 'final_gate_protocol.log'),
}
for name, (pred, sim, proto) in regressions.items():
    p = R / pred
    if not p.exists():
        continue
    res = list(csv.DictReader(p.open()))
    func[name] = {
        'tested': len(res),
        'mismatches': sum(a != b for a, b in zip(rows, res)),
        'complete': len(res) == len(rows),
        'simulation_log': pass_line('reports/' + sim),
        'directed_protocol_log': pass_line('reports/' + proto),
    }
(R / 'functional_results.json').write_text(json.dumps(func, indent=2) + '\n')

# ------------------------------------------------------------------ physical
rep = json.loads(text(f'physical/logs/{BASE}/6_report.json') or '{}')
geo = {}
for line in text('reports/physical_geometry.txt').splitlines():
    f = line.split()
    if f[0] == 'type':
        geo[f[1]] = {'count': int(f[3]), 'area_um2': int(f[5]) / 1e6}
    elif f[0] in ('die_dbu', 'core_dbu'):
        x0, y0, x1, y1 = map(int, f[1:])
        geo[f[0][:-4] + '_um'] = [(x1 - x0) / 1000, (y1 - y0) / 1000]
    elif f[0] == 'total_instances':
        geo['total_instances'] = int(f[1])
non_fill = [v for k, v in geo.items() if k.startswith('CORE') and k != 'CORE_SPACER']
core_area = geo['core_um'][0] * geo['core_um'][1]

route = text(f'physical/logs/{BASE}/5_route.log') or text(f'physical/logs/{BASE}/5_2_route.log')
grt = text(f'physical/logs/{BASE}/5_1_grt.log')
drt_viol = [int(x) for x in re.findall(r'Number of violations = (\d+)', route)]
drc_deck = text('tools/OpenROAD-flow-scripts/flow/platforms/sky130hd/drc/sky130hd.lydrc')
drc_log = text(f'physical/logs/{BASE}/6_drc.log')
deck_flags = {k: v == 'true' for k, v in re.findall(r'^(FEOL|BEOL|OFFGRID)\s*=\s*(\w+)', drc_deck, re.M)}

physical = {
    'timing_corner': 'sky130_fd_sc_hd tt_025C_1v80, OpenRCX extracted parasitics',
    'clock_period_ns': CLK_NS,
    'setup_ws_ns': rep.get('finish__timing__setup__ws'),
    'setup_tns_ns': rep.get('finish__timing__setup__tns'),
    'hold_ws_ns': rep.get('finish__timing__hold__ws'),
    'hold_tns_ns': rep.get('finish__timing__hold__tns'),
    'clock_uncertainty_ns_in_slack': 0.4,
    'sta_fmax_mhz_single_corner': (rep.get('finish__timing__fmax') or 0) / 1e6,
    'max_slew_violations': rep.get('finish__timing__drv__max_slew'),
    'max_cap_violations': rep.get('finish__timing__drv__max_cap'),
    'max_fanout_violations': rep.get('finish__timing__drv__max_fanout'),
    'clock_skew_setup_ns': rep.get('finish__clock__skew__setup'),
    'die_um': geo['die_um'], 'core_um': geo['core_um'],
    'stdcell_count_excl_fill': sum(v['count'] for v in non_fill),
    'stdcell_area_um2_excl_fill': sum(v['area_um2'] for v in non_fill),
    'utilization_excl_fill': sum(v['area_um2'] for v in non_fill) / core_area,
    'cells_by_type': {k: v for k, v in geo.items() if k.startswith('CORE')},
    'total_instances_incl_fill': geo.get('total_instances'),
    'sequential_cells': rep.get('finish__design__instance__count__class:sequential_cell'),
    'clock_buffers': rep.get('finish__design__instance__count__class:clock_buffer'),
    'flow_warnings': rep.get('finish__flow__warnings__count'),
    'flow_errors': rep.get('finish__flow__errors__count'),
    'detailed_route_final_violations': drt_viol[-1] if drt_viol else None,
    'antenna': {
        'global_route_initial_violations': int(m.group(1)) if (m := re.search(r'Found (\d+) antenna violations', grt)) else None,
        'global_route_jumpers_and_nets': [int(x) for x in m.groups()] if (m := re.search(r'Inserted (\d+) jumpers for (\d+) nets', grt)) else None,
        'global_route_diodes': sum(int(x) for x in re.findall(r'GRT-0015\] Inserted (\d+) diodes', grt)),
        'post_detailed_route_violations': int(m.group(1)) if (m := re.search(r'Found (\d+) antenna violations', route)) else None,
        'post_detailed_route_diodes': sum(int(x) for x in re.findall(r'GRT-0015\] Inserted (\d+) diodes', route)),
        'final_check_net_violations': [int(x) for x in re.findall(r'ANT-0002\] Found (\d+) net violations', route)][-1:],
        'final_check_pin_violations': [int(x) for x in re.findall(r'ANT-0001\] Found (\d+) pin violations', route)][-1:],
        'antenna_cells_in_final_layout': geo.get('CORE_ANTENNACELL', {}).get('count'),
        'checker': 'OpenROAD check_antennas (LEF antenna rules); not a KLayout antenna deck',
    },
    'klayout_drc': {
        'violations': int(text(f'physical/reports/{BASE}/6_drc_count.rpt').strip() or -1),
        'deck': 'ORFS platforms/sky130hd/drc/sky130hd.lydrc',
        'deck_sections_enabled': deck_flags,
        'sections_run': re.findall(r'^(\S+) section$', drc_log, re.M),
    },
    'klayout_lvs': {
        'result': 'match' if 'Congratulations! Netlists match.' in text(f'physical/logs/{BASE}/6_lvs.log') else 'not matched',
        'reference': '6_final.cdl (from 6_final.v) vs netlist extracted from 6_final.gds',
    },
    'lec_post_resizer': 'IDENTICAL' if 'Circuits are IDENTICAL' in text(f'physical/logs/{BASE}/4_rsz_lec_check.log') else None,
    'lec_final': 'IDENTICAL' if 'Circuits are IDENTICAL' in text(f'physical/logs/{BASE}/6_final_lec_check.log') else None,
}

# --------------------------------------------------------------------- power
def pw(name):
    return json.loads(text(f'reports/{name}.json'))['Total']


def coverage(name):
    t = text(f'reports/{name}.rpt')
    return {k: int(v) for k, v in re.findall(r'^(vcd|unannotated)\s+(\d+)', t, re.M)}


act, idle, vless = pw('power_activity'), pw('power_idle'), pw('power_vectorless')
act_s = vcd_end_ps('reports/mapped_activity.vcd') * 1e-12
idle_s = vcd_end_ps('reports/idle_activity.vcd') * 1e-12
n_vec = len(list(csv.DictReader((R / 'activity_predictions.csv').open())))
run_cycles = sum(cycles[:n_vec])
win_cycles = act_s / (CLK_NS * 1e-9)
load_cycles = 256 * n_vec
power = {
    'conditions': 'OpenSTA report_power, TT 25C 1.8 V Liberty, 25 MHz SDC clock, final SPEF; zero-delay VCD (no glitch power)',
    'activity_netlist': 'physical/results/sky130hd/ecg_snn_core/base/1_2_yosys.v (synthesis-mapped), annotated onto 6_final.odb',
    'activity_window': {
        'vectors': n_vec, 'duration_us': act_s * 1e6, 'clock_cycles': win_cycles,
        'load_cycles': load_cycles, 'run_cycles': run_cycles,
        'other_cycles': win_cycles - load_cycles - run_cycles,
        'longest_beat_run_cycles': max(cycles[:n_vec]),
        'coverage': coverage('power_activity_coverage'),
    },
    'idle_window': {'duration_us': idle_s * 1e6, 'coverage': coverage('power_idle_coverage'),
                    'state': 'clock running, full valid buffer, start low, not busy'},
    'activity_W': act, 'idle_W': idle, 'vectorless_W': vless,
    'energy_activity_window_uJ': act['total'] * act_s * 1e6,
    'energy_same_window_if_idle_uJ': idle['total'] * act_s * 1e6,
    'incremental_over_idle_uJ': (act['total'] - idle['total']) * act_s * 1e6,
    'mean_energy_per_vector_in_window_uJ': act['total'] * act_s * 1e6 / n_vec,
    'mean_incremental_per_vector_nJ': (act['total'] - idle['total']) * act_s * 1e9 / n_vec,
    'leakage_energy_activity_window_nJ': act['leakage'] * act_s * 1e9,
    'clock_group_W': json.loads(text('reports/power_activity.json'))['Clock']['total'],
}

summary = {'functional': func, 'physical': physical, 'power': power}
(R / 'final_summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
