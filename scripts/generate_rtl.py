"""Reproducible, narrow ASIC adaptation of the pinned MIT-licensed RTL."""
from pathlib import Path
import re
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'vendor/HDL-SpikingNet-ECG'
OUT = ROOT / 'rtl'
OUT.mkdir(exist_ok=True)
for path in SRC.glob('*.v'):
    if path.name == 'tb__top.v':
        continue
    s = path.read_text()
    if path.name == 'top.v':
        s = s.replace('module top (clk , resetn, output_class, no_spike, end_process);',
            'module snn_network (clk, resetn, load_valid, load_addr, load_data, output_class, no_spike, end_process);\ninput load_valid;\ninput [7:0] load_addr;\ninput [3:0] load_data;')
        s = s.replace('reg [3:0] in_period[0:255];', 'reg [3:0] in_period[0:255];\nalways @(posedge clk) if (load_valid) in_period[load_addr] <= load_data;')
        s = s.replace('wire [7:0] ctrl_addr;', 'wire ctrl_spk;\nwire [7:0] ctrl_addr;')
        s = s.replace('output_controller out_controller(.clk(clk),', 'output_controller out_controller(.clk(clk), .resetn(resetn),')
        for kind, count in [('hid', 8), ('out', 6)]:
            mod = 'hidden_neuron' if kind == 'hid' else 'output_neuron'
            for i in range(count):
                s = s.replace(f'{mod} neuron_{kind}{i}(', f'{mod} #(.ROM_ID({i})) neuron_{kind}{i}(')
    if path.name in ('hidden_neuron.v', 'output_neuron.v'):
        kind = 'hidden' if path.name.startswith('hidden') else 'out'
        s = s.replace('parameter data_bit = 7;', 'parameter data_bit = 7;\nparameter ROM_ID = 0;')
        s = s.replace(f'ROMFile_{kind} ROM0', f'ROMFile_{kind} #(.ROM_ID(ROM_ID)) ROM0')
        a = s.index(f'module ROMFile_{kind}')
        b = s.index('endmodule', a) + len('endmodule')
        bits, count, prefix = (8, 8, 'hid') if kind == 'hidden' else (3, 6, 'out')
        rom = f'module ROMFile_{kind} #(parameter n_bit=7, parameter ROM_ID=0)(input [{bits-1}:0] address, output [n_bit:0] data, input read_en);\nreg [7:0] value;\nassign data = read_en ? value : 8\'d0;\nalways @* begin\nvalue=0;\ncase (ROM_ID)\n'
        for i in range(count):
            vals = [int(x, 16) for x in (SRC / f'hex_files/ROM_{prefix}{i}.hex').read_text().split()]
            assert len(vals) == 2**bits and max(vals) < 256
            rom += f'{i}: begin case(address)\n'
            rom += ''.join(f"{bits}'d{j}: value=8'h{v:02x};\n" for j,v in enumerate(vals))
            rom += "default: value=0;\nendcase end\n"
        rom += 'default: value=0;\nendcase\nend\nendmodule'
        s = s[:a] + rom + s[b:]
        if kind == 'hidden':
            s = s.replace('  ROM_address <= addr_in;\n  enable <= spike_in;\n  IF_in <= ROM_out;',
                '  if (resetn) begin ROM_address <= 0; enable <= 0; IF_in <= 0; end\n  else begin ROM_address <= addr_in; enable <= spike_in; IF_in <= ROM_out; end')
        else:
            s = s.replace('  IF_in <= ROM_out;', '  if (resetn) IF_in <= 0; else IF_in <= ROM_out;')
    if path.name == 'output_controller.v':
        s = s.replace('module output_controller(clk,', 'module output_controller(resetn, clk,').replace('input clk;', 'input clk, resetn;')
        s = s.replace('  spike_out <= spike_out_D;\n  addr_out <= addr_out_D;',
            '  if (resetn) begin spike_out <= 0; addr_out <= 0; end\n  else begin spike_out <= spike_out_D; addr_out <= addr_out_D; end')
    # Use Z-only wildcard decoding: X values must not look like valid spikes.
    s = re.sub(r"(\d+'b)([01x_]+)", lambda m: m[1]+m[2].replace('x','?'), s).replace('casex', 'casez')
    (OUT / ('snn_network.v' if path.name == 'top.v' else path.name)).write_text('// Derived from HDL-SpikingNet-ECG (MIT); see vendor license.\n'+s)

manifest = {str(p.relative_to(SRC)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(SRC.rglob('*')) if p.is_file() and '.git' not in p.parts}
(ROOT/'reports/source_hashes.json').write_text(json.dumps(manifest, indent=2)+'\n')
print('Generated ASIC network and constant ROMs; original vendor sources unchanged.')
