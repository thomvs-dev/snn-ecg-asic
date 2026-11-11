# Reference RTL audit

Source: alirezaamir/HDL-SpikingNet-ECG, commit
`c6e7fee7040968e4cce95aa7d0394c6f039a247f`, MIT license.
The previous audit was read before fetching a complete checkout. Its partial
clone could not supply all objects, so the full repository was fetched into vendor.

## Actual implementation

256 input neurons -> 8 parallel hidden neurons -> 6 parallel output neurons.
Each input has a four-bit period and counter, and a pending-spike bit. Sixteen
priority encoder groups feed a second priority encoder; the lowest input index
wins. Hidden outputs similarly use a lowest-index priority encoder.

The main counter reloads 2500 on zero, so its tick interval is **2501 clocks**.
Input counters reload their period on zero and decrement on timer ticks.
Period zero produces a continuously asserted pending spike and can starve higher
indices. Pending bits coalesce events; this is not an unbounded event queue.

Weights are **unsigned eight-bit** values: 8 x 256 hidden and 6 x 8 output
weights, 2096 bytes total. Membranes are unsigned 11-bit registers. Hidden
threshold is strictly `>320`, output threshold strictly `>112`. Hidden and
output membranes reset to zero after firing. Hidden refractory parameter is
zero. There is no membrane leak. Arithmetic wraps at 11 bits; the overflow
wire is unused. With these thresholds and eight-bit nonnegative inputs,
normal membrane accumulation cannot reach 2048 before firing. Signed weights
or saturating arithmetic would change this reference model and are not added.

The first output spike terminates inference. Priority order is neuron 0 to 5;
neurons 0/3 map to code 0, 1/4 to 1, 2/5 to 2. Code 3 means no output spike.
The arbitrator also terminates after 12 timer ticks. If timeout and a spike
coincide, both no_spike and a valid class may be returned; preserved as upstream.
No authoritative disease-name mapping for these numeric codes accompanies
the files. Do not label them NOR/VEB/FUS without additional provenance.

## Original testbench and evidence limits

The testbench supplies 500 vectors of 256 six-bit numbers, then silently
truncates each to four bits in `top.in_period`. It loads all weights through
hierarchical `$readmemh` calls. No labels, patient identifiers, preprocessing
exporter, training code or model-to-patient mapping accompany this checkout.
Baseline agreement is measurable; clinical accuracy and F1 are not.
Despite its name, `resetn` is **active high**, synchronous. The original bench
holds reset for three edges between beats. Original hidden weight pipeline,
output input-current pipeline and output controller lack explicit reset.
The unmodified design has no usable input-loading ports or implemented ROM
contents. There are no vendor FPGA primitives in these source modules.

The file has exactly 128,000 values, range 4..61; 125,332 exceed 15 and
1,793 have a zero low nibble. The original self-triggering `always @(clk)`
oscillator did not start in Icarus 12 from its declaration initialization.
The instrumented baseline replaces it with `always #500 clk=~clk`, retaining
the intended 1000 ns period. A reporting-only division by zero at num=0 is
also fixed. Neither change modifies the network RTL. The initial failed
attempt reached the watchdog with no clock edges or predictions.

## ASIC changes

`scripts/generate_rtl.py` preserves topology, pipeline depth, timer, arithmetic
and priority. It generates constant case ROMs from the exact hex files, adds
missing pipeline resets, explicitly declares ctrl_spk, and replaces casex with
casez plus question-mark patterns so unknown inputs are not treated as 1/0.
The wrapper loads 256 four-bit words sequentially, then permits start. A PREP
edge ensures the final word has reached the input counter under reset. Neuron
state is held in reset outside RUN. Input storage does not need reset because
all 256 locations must be overwritten after reset or completion before RUN.
This avoids 1024 unnecessary resettable storage bits while preventing stale
data from being used. The wrapper resets all externally observable results.

## Paper comparison

Amirshahi and Hashemi, TBCAS 2019, DOI 10.1109/TBCAS.2019.2948920,
describes segmentation, Gaussian processing, STDP pattern extraction and
R-STDP classification, with inhibitory neurons used only during training.
Its Brian2 evaluation uses patient-specific training and 200 ms inference
at a 1 ms neuron timestep, with a spike-count winner. Its four-class confusion
matrix (NOR/VEB/FUS/Q) is reduced to VEB versus non-VEB for Table II.
Table II reports 97.9% accuracy and 88.0% F1. Its 1.78 uJ/beat is an event-cost
estimate using 50 pJ/neuron spike and 147 pJ/synaptic event.

This repository instead has three numeric class codes, first-spike termination,
four-bit periodic input encoding, no explicit Gaussian/segmentation stages, and
a twelve-tick timeout. It is not a bit-exact hardware reproduction of the
complete paper model. Paper metrics must not be assigned to this core.
