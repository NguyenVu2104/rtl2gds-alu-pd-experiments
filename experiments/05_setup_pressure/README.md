# Experiment 05: Setup pressure

Design: `alu32_reg`. Platform: sky130hd. Flow: OpenROAD-flow-scripts.

Question of this experiment: what happens to timing, area and `repair_timing` when the clock period is made shorter than what the baseline run needed?

## Setup

- Design `alu32_reg`: the combinational `alu32` between 100 flip-flops (`a` 32, `b` 32, `op` 4, `y` 32).
- ORFS commit `d90873f47b79f343c6be15210ce398e1383c08d2`. OpenROAD `26Q2-1164-g08f67ee5ec`.
- Floorplan settings are the same in every run: `CORE_UTILIZATION` 40, `CORE_ASPECT_RATIO` 1, `CORE_MARGIN` 2, `PLACE_DENSITY` 0.60.
- SDC: one clock `clk`, input delay 0 and output delay 0 relative to `clk`.
- Baseline: period 10.0 ns, run to `finish`.
- T = 4.86 ns. This is `clk period_min` printed by `report_clock_min_period` after CTS in the baseline run.
- Variants. The only changed input is the period in the SDC. Each variant has its own SDC file and its own `FLOW_VARIANT`.

| FLOW_VARIANT | Period (ns) | SDC file | Last target run |
|---|---:|---|---|
| `base` | 10.0 | `constraint.sdc` | `finish` |
| `period_4p374` (0.9T) | 4.374 | `constraint_period_4p374.sdc` | `cts` |
| `period_3p888` (0.8T) | 3.888 | `constraint_period_3p888.sdc` | `cts` |
| `period_3p402` (0.7T) | 3.402 | `constraint_period_3p402.sdc` | `finish` |

- The SDC is given with `SDC_FILE=` on the `make` command line. `make -p -n` shows this value as `# command line`, so it replaces the value in `config.mk`.
- The netlist after synthesis (`1_2_yosys.v`) has the same md5 in all four runs, although `clock_period.txt` (the period given to ABC) is 10.0, 4.374, 3.888 and 3.402. Every difference below therefore appears after synthesis.

## Metrics

- **Worst slack, WNS, TNS**: the lines `worst slack max`, `wns max`, `tns max` in the report of each stage. WNS and TNS are 0.00 when no path violates.
- **period_min** = period − worst slack. `report_clock_min_period` prints it after CTS, global route and finish. Reports are rounded to 0.01 ns, so a difference of 0.01 ns is noise.
- **Design area**: the line `Design area` in each stage log, in µm². Fill cells are not counted.
- **repair_timing table**: columns `Removed Buffers`, `Resized Gates`, `Inserted Buffers`, `Cloned Gates`, `Pin Swaps`, `Area` (relative change), `WNS`, `Viol Endpts`. The summary lines are `RSZ-0051` (resized), `RSZ-0043` (pin swaps), `RSZ-0040` (inserted buffers), `RSZ-0059` (removed buffers), `RSZ-0062` (not all setup violations repaired), `RSZ-0098` (no setup violation).
- **Timing-driven placement**: in `3_3_place_gp.log`, `GPL-0106` is the worst slack and `GPL-0107` is the `repair_design` area change at each of the two timing-driven iterations.
- **Instance groups**: instances are grouped by name prefix (`place`, `rebuffer`, `input`, `output`, `clkload`, yosys `_N_`). The counts come from the database of each stage.

## Results

### Worst slack (ns)

| Stage | base (10.0) | 0.9T (4.374) | 0.8T (3.888) | 0.7T (3.402) |
|---|---:|---:|---:|---:|
| floorplan, before `repair_timing` | 6.05 | 0.42 | −0.07 | −0.55 |
| floorplan final | 6.05 | 0.42 | 0.01 | −0.06 |
| global place | 5.27 | 0.46 | 0.29 | −0.17 |
| detailed place | 5.15 | 0.34 | 0.15 | −0.22 |
| cts final | 5.14 | 0.31 | 0.10 | −0.09 |
| global route | 4.65 | not run | not run | −0.15 |
| finish | 5.06 | not run | not run | 0.04 |

Floorplan, before `repair_timing`: for base and 0.9T no repair ran (`RSZ-0098`), so the value is the report value. For 0.8T and 0.7T it is the first row of the `repair_timing` table. In the 0.7T run WNS is 0 at `finish` (`wns max 0.00`).

### period_min (ns)

| Stage | base | 0.9T | 0.8T | 0.7T |
|---|---:|---:|---:|---:|
| floorplan, before `repair_timing` | 3.95 | 3.95 | 3.95 | 3.95 |
| cts (`report_clock_min_period`) | 4.86 | 4.06 | 3.79 | 3.50 |
| global route | 5.35 (computed) | not run | not run | 3.55 (`report_clock_min_period`) |
| finish | 4.94 (computed) | not run | not run | 3.36 (`report_clock_min_period`) |

"Computed" means 10.0 − worst slack. The floorplan row is period − slack with the values in the first table (3.954 for 0.9T, 0.8T and 0.7T).

### Design area (µm²)

| Stage | base | 0.9T | 0.8T | 0.7T |
|---|---:|---:|---:|---:|
| synthesis (Chip area) | 10734.04 | 10734.04 | 10734.04 | 10734.04 |
| floorplan | 10734 | 10734 | 10735 | 10792 |
| global place (3_3) | 11899 | 12025 | 12238 | 12956 |
| cts | 12194 | 12318 | 12531 | 13323 |
| global route to finish | not measured | not run | not run | 13434 |
| change vs base at cts | 0 | +124 (+1.0%) | +337 (+2.8%) | +1129 (+9.3%) |

Difference to the baseline for 0.7T: floorplan +58, global place +1057, cts +1129. Per stage this is +58, +999 and +72 µm². The baseline area after global route was not collected, so the global-route step (+111 µm² for 0.7T, 13323 → 13434) has no baseline value.

### repair_timing calls

| Stage | Variant | Violating endpoints (before → after) | WNS (ns, before → after) | Removed buffers | Resized gates | Inserted buffers | Cloned gates | Pin swaps | Area (log) | End message |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---|
| floorplan | 0.8T | 1 → 0 | −0.066 → +0.012 | 0 | 1 | 0 | 0 | 0 | +0.0% | repaired |
| floorplan | 0.7T | 2 → 1 | −0.552 → −0.055 | 0 | 21 | 0 | 0 | 9 | +0.5% | `RSZ-0062` |
| cts | 0.7T | 3 → 1 | −0.244 → −0.093 | 1 | 6 | 3 | 0 | 8 | +0.4% | `RSZ-0062` |
| global route | 0.7T | 12 → 2 | −0.342 → −0.168 | 1 | 25 | 1 | 0 | 4 | +0.8% | `RSZ-0062` |

- Every resize is an upsize (`0 up match, 0 down, 0 VT`).
- `RSZ-0098` (no setup violation) is printed at floorplan for base and 0.9T, and at cts for base, 0.9T and 0.8T.
- The move sequence printed by `RSZ-0100` has three moves at floorplan (`UnbufferMove SizeUpMove SwapPinsMove`) and six at cts and global route (`UnbufferMove SizeUpMove SwapPinsMove BufferMove CloneMove SplitLoadMove`).
- The command at floorplan has `-sequence unbuffer,sizeup,swap,vt_swap`. At global route the command has no `-match_cell_footprint`. At floorplan and cts it has.
- The 0.7T run took 16 seconds in `repair_timing` at global route.

### Timing-driven global placement (`3_3_place_gp.log`)

| | base | 0.9T | 0.8T | 0.7T |
|---|---:|---:|---:|---:|
| `GPL-0106` worst slack, iteration 1 (ns) | 4.85 | 0.63 | 0.29 | −0.08 |
| `GPL-0106` worst slack, iteration 2 (ns) | 5.16 | 0.43 | 0.28 | −0.11 |
| `GPL-0107` `repair_design` area, iteration 1 (µm²) | 104.200 | 216.808 | 351.938 | 944.306 |
| `GPL-0107` `repair_design` area, iteration 2 (µm²) | 51.970 | 61.460 | 134.087 | 215.684 |
| `GPL-0107` total (µm²) | 156.170 | 278.268 | 486.025 | 1159.990 |
| total minus base (µm²) | 0 | +122.1 | +329.9 | +1003.8 |
| area at 3_3 minus base, without floorplan change (µm²) | 0 | +126 | +338 | +999 |

At `GPL-0101` iteration 1 the base run and the 0.9T run print the same iteration (213) and the same HPWL (19347411).

### Instances (name groups in the database)

| | base | 0.9T | 0.8T | 0.7T |
|---|---:|---:|---:|---:|
| total at 3_3 | 1714 | 1730 | 1759 | 1851 |
| `place*` at 3_3 | 18 | 34 | 63 | 155 |
| total at cts | 1730 | 1746 | 1775 | 1869 |
| `place*` at cts | 18 | 34 | 63 | 154 |
| `rebuffer*` at cts | 0 | 0 | 0 | 3 |

- The groups `input` (68), `output` (32), yosys `_N_` (1161), `(other)` (435 at 3_3, 444 at cts) and `clkload` (7 at cts) have the same count in every run.
- Master changes at 3_3: `buf_4` 18 → 34 (0.9T), 18 → 63 (0.8T), 18 → 154 plus one `buf_12` (0.7T). The other changes are single cells (`nor3_2` → `nor3_4`, `clkinv_1` → `clkinv_2`, `o21ai_1` → `o21ai_2`, and similar). The full list is in `data/instances_by_prefix_and_master.txt`.

### Critical path after cts

The endpoint is `y[31]` in every run. The startpoint changes.

| | base | 0.9T | 0.8T | 0.7T |
|---|---|---|---|---|
| startpoint | `b_q[2]` | `a_q[18]` | `a_q[9]` | `b_q[1]` |
| flip-flop (fanout, clock-to-Q ns) | `dfxtp_2` (35, 0.83) | `dfxtp_1` (7, 0.46) | `dfxtp_1` (9, 0.53) | `dfxtp_4` (2, 0.39) |
| first gate (fanout, delay ns) | `inv_2` (28, 0.49) | `inv_1` (3, 0.11) | `inv_1` (1, 0.08) | `inv_8` (2, 0.03) |
| from the launching clock edge to `_1416_/Y` (ns) | 3.06 | 2.28 | 2.00 | 1.82 |
| from `_1416_/Y` to the D pin of `y[31]` (ns) | 1.69 | 1.66 | 1.66 | 1.56 |

The cell `_1416_` (`o41ai_4`) is on the path in all four runs. The instance `place136` (`buf_4`) is on the 0.9T path. The instance `rebuffer384` (`buf_4`) is on the 0.7T path.

## Conclusions

**Q1. How does the setup slack change from stage to stage?**
- Floorplan: before any repair the period_min is 3.95 ns in all four runs. This stage uses wire load models (`EST-0027` in `2_1_floorplan.log`).
- After placement, period_min depends on the period that was given. At cts it is 4.86 (10.0), 4.06 (4.374), 3.79 (3.888) and 3.50 ns (3.402). The same netlist gives these four different numbers, so period_min is not a fixed property of the netlist. It is a result of the flow under a given constraint.
- Baseline (10.0 ns): the slack drops from 6.05 (floorplan) to 5.27 (global place), 5.14 (cts) and 4.65 (global route), then rises to 5.06 (finish).
- At 0.9T and 0.8T the slack after global place is higher than at floorplan (+0.04 and +0.28 ns). At 0.7T it is lower (−0.11 ns).
- At 0.7T the worst slack is negative at every stage before routing (−0.17, −0.22, −0.09, −0.15 ns) and is +0.04 ns at finish. The gain from global route to finish is +0.19 ns here and +0.41 ns in the baseline.

**Q2. Which `repair_timing` moves run, and at which stage?**
- No stage needed `repair_timing` at 0.9T. At 0.8T only floorplan needed it, and one resize repaired the single violating endpoint.
- At 0.7T `repair_timing` worked at floorplan, cts and global route. It used resizes (all upsizes), pin swaps, and at cts and global route a few buffer changes (one removed and three inserted at cts, one removed and one inserted at global route). It never cloned a gate.
- The three buffers inserted at cts appear as three `rebuffer*` instances in the database, which matches `RSZ-0040`. No `split*` or `clone*` instance exists in any run.

**Q3. How much do area and instance count grow when the period gets shorter?**
- At cts: +124, +337 and +1129 µm² (+1.0%, +2.8%, +9.3%) for 0.9T, 0.8T and 0.7T. The instance count grows by 16, 45 and 139. The 0.7T run ends at 13434 µm² after global route.
- Most of the growth is not made by `repair_timing`. At 0.7T, 999 of the 1129 µm² (88%) of the growth at cts appear in global place (3_3). `repair_timing` calls change the design area by +0.5%, +0.4% and +0.8% in their own logs.
- In 3_3 the only instance group that changes is `place*` (18, 34, 63, 155). The extra area per added `place*` instance is 7.9, 7.5 and 7.3 µm² for 0.9T, 0.8T and 0.7T (126/16, 338/45, 999/137).
- The extra area in 3_3 matches the sum of the `GPL-0107` changes within 4 to 8 µm² (+122.1 vs +126, +329.9 vs +338, +1003.8 vs +999). Timing-driven placement runs `repair_design`, and the amount of buffering it adds grows when the period gets shorter, even when the slack it reports is still positive (0.63 ns at 0.9T and 0.29 ns at 0.8T in iteration 1).

**Q4. At which period does `repair_timing` stop being able to fix the design?**
- The break is between 0.8T and 0.7T. At 0.8T the floorplan repair fixes the only violation (WNS +0.012 ns). At 0.7T every call ends with `RSZ-0062` and WNS stays negative: −0.055 (floorplan), −0.093 (cts) and −0.168 (global route, in the repair table; the report `5_global_route.rpt` shows −0.15).
- The final design at 0.7T still meets the period: `6_finish.rpt` shows `wns max 0.00` and worst slack +0.04 ns, with period_min 3.36 ns (0.69 T).
- This experiment did not find a period where the finished design fails. The margin at 0.7T is 0.04 ns.

## Open questions

1. Why does the amount of buffering done by `repair_design` inside timing-driven global placement depend on the clock period, when the slack it reports is still positive?
2. How much of the faster result after placement comes from the added `place*` buffers, and how much from other changes in timing-driven placement (for example the net weights)?
3. Did the `place*` buffers land on the high-fanout nets of the baseline critical path (the nets with fanout 35 and 28)?
4. Why does the `repair_timing` command at floorplan list `vt_swap` in `-sequence` but print only three moves? Why are no gates cloned and no loads split in any run?
5. Why does the worst slack get worse during the first iterations of `repair_timing` at global route in the 0.7T run (−0.342 ns at iteration 0, −0.379 ns at iteration 10)?
6. Why is the slack at finish higher than at global route, by +0.41 ns in the baseline and by +0.19 ns at 0.7T?
7. Why does the last row of the repair table at global route show WNS −0.168 ns, when `5_global_route.rpt` shows −0.15 ns?
8. Why does the `repair_timing` command at global route not have `-match_cell_footprint`, while the commands at floorplan and cts have it?
9. How far below 3.402 ns can the period go before the finished design fails?

## Data

Directory `data/`:

| File | Content |
|---|---|
| `count_instances_by_prefix.py` | Script that counts instances by name prefix and compares masters with the baseline (`openroad -python`) |
| `instances_by_prefix_and_master.txt` | Output of the script above for `3_3_place_gp.odb` and `4_1_cts.odb` |
| `<FLOW_VARIANT>/run_info.txt` | Variant name, period, ORFS commit, OpenROAD version, md5 of the netlist after synthesis and of `4_1_cts.odb` |
| `<FLOW_VARIANT>/area_by_stage.txt` | `Design area` line of every stage log |
| `<FLOW_VARIANT>/slack_by_stage.txt` | WNS, TNS, worst slack and `report_clock_min_period` of every stage report that exists |
| `<FLOW_VARIANT>/place_3_3_evidence.txt` | `GPL-0100`, `GPL-0101`, `GPL-0106` to `GPL-0110` and `RSZ-00xx` lines of `3_3_place_gp.log` |
| `<FLOW_VARIANT>/repair_timing_floorplan.txt` | `repair_timing` block of `2_1_floorplan.log` |
| `<FLOW_VARIANT>/repair_timing_cts.txt` | `repair_timing` block of `4_1_cts.log` |
| `<FLOW_VARIANT>/repair_timing_grt.txt` | `repair_timing` block of `5_1_grt.log` (only for runs that reached global route) |
| `<FLOW_VARIANT>/critical_path_cts.txt` | Longest setup path of `4_cts_final.rpt` |

`<FLOW_VARIANT>` is one of `base`, `period_4p374`, `period_3p888`, `period_3p402`.