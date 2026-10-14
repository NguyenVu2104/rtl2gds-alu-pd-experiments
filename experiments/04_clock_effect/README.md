# Experiment 04: Clock effect

Question: what does a clock change in the flow? `alu32` (combinational, no clock) is compared with `alu32_reg`, which is the same ALU with a register stage on every input and output and one clock.

All `alu32` numbers come from `experiments/01_area_evolution`.

## 1. Setup

- Design `alu32_reg`: input registers for `a` (32), `b` (32) and `op` (4), then `alu32`, then an output register for `y` (32). 100 flip-flops in total, no reset.
- Constraints: clock `clk`, period 10.0 ns. Input delay and output delay are 0.0 ns relative to `clk`.
- Config: same as `alu32`. `CORE_UTILIZATION` 40, `CORE_ASPECT_RATIO` 1, `CORE_MARGIN` 2, `PLACE_DENSITY` 0.60.
- Tools: ORFS commit, OpenROAD and Yosys versions are in `data/base/run_info.txt`.
- The baseline (`FLOW_VARIANT=base`) runs to `finish`. The CTS variants stop at `cts`.

Data (all under `experiments/04_clock_effect/data/`):

| File | Content |
|---|---|
| `base/stage_evidence.txt` | message codes of every stage log, each line starts with its log name |
| `base/synth_stat.txt` | synthesis cell statistics and Chip area |
| `base/cell_type_report.txt` | Cell type report at the end of the flow |
| `base/timing_evidence.txt` | wns, tns, worst slack per stage, clock min period, skew, violation counts |
| `base/cell_evidence.txt` | Liberty area of the flip-flop and port buffer cells, cell counts after synthesis and at the end |
| `base/run_info.txt` | ORFS commit, tool versions, md5 of `5_route.odb` |
| `base/route_summary.txt` | wire length and vias printed by the router at every detail route iteration |
| `base/wire_length_by_net_type.txt` | wire length measured from `5_route.odb`, per net type, for `alu32_reg` and `alu32` |
| `base/clock_net_cells.txt` | cells that touch a CLOCK net, by master |
| `cts_cluster_size_5/cts_evidence.txt` | CTS command, CTS messages, md5 of `4_1_cts.odb` |
| `cts_cluster_size_50/cts_evidence.txt` | same |
| `cts_cluster_diameter_10/cts_evidence.txt` | same |
| `cts_variant_comparison.txt` | md5 of `4_1_cts.odb` of the baseline and the three variants |
| `measure_wire_length.py` | wire length per net type, run with `openroad -python <absolute path> -exit` |
| `list_clock_net_cells.py` | cells that touch a CLOCK net, run the same way |

Both scripts read `work/results/.../5_route.odb`, which is not pushed. Run the baseline first.

## 2. Metrics

- Design area: the `Design area` line in each stage log. It counts tap cells, buffers, flip-flops and diodes. It does not count fill cells.
- Chip area: from `synth_stat.txt`, summed from Liberty cell areas after synthesis.
- Total in the Cell type report (`6_report.log`): counts fill cells. It is equal to the core area (26206.38 µm² for `alu32_reg`).
- Wire length (router): `Total wire length` in `5_2_route.log`. The log prints it after every iteration, so the last block is the final value.
- Wire length (by net type): sum of the wire length of each net in `5_route.odb`, grouped by the net signal type (SIGNAL or CLOCK).

## 3. Results

Design area (µm²):

| Stage | alu32 | alu32_reg |
|---|---:|---:|
| synthesis (Chip area) | 8807.197 | 10734.045 |
| after tap cells (2_3) | 9158 | 11153 |
| after global placement (3_3) | 9856 | 11899 |
| after CTS (4_1) | 9856 | 12194 |
| end of flow | 9861 | 12194 |
| growth from synthesis | +11.96% | +13.6% |

Instances: 1258 (`alu32`) and 1352 (`alu32_reg`) after synthesis; 1538 and 1687 after tap cells.

Wire length (µm) and vias:

| | alu32 | alu32_reg | Change |
|---|---:|---:|---:|
| SIGNAL nets (from odb) | 38631.08 | 40058.22 | +1427.14 (+3.7%) |
| CLOCK nets (from odb) | 0 | 1655.97 | +1655.97 |
| All nets (from odb) | 38631.08 | 41714.19 | +3083.11 (+8.0%) |
| Router total | 38634 | 41709 | +3075 (+8.0%) |
| Vias (router) | 10447 | 10991 | +544 (+5.2%) |

The odb total differs from the router total by 2.92 µm (`alu32`) and 5.19 µm (`alu32_reg`).

Timing: no setup or hold violation at any stage. `repair_timing` after CTS reported no setup and no hold violation and inserted nothing.

## 4. Conclusions

**Q1. At which stage does `alu32_reg` differ from `alu32`?**
At every stage up to CTS.

- Synthesis: 100 `dfxtp_1` flip-flops, 100 × 20.0192 = 2001.92 µm². The total grows by only 1926.848 µm², so the combinational part is 75.072 µm² smaller than in `alu32` alone (see open question 1).
- Tap cells: the core is larger (163.300 × 160.480 µm after snapping, 26206.38 µm²), so there are 335 tap cells instead of 280. 335 × 1.2512 = 419.152 µm². The instance count goes from 1352 to 1687, which is +335.
- Global placement: +746 µm². This includes 100 port buffers (100 × 10.0096 = 1000.96 µm²) and `repair_design` (+156.17 µm² over two rounds). The area of the synthesis buffers removed in this step was not totaled.
- CTS: +295 µm², 16 new cells (see Q2). Nothing changes after CTS.

**Q2. Which cells does the clock add?**

- Synthesis maps all 100 flip-flops to `dfxtp_1`. At the end of the flow 96 are `dfxtp_1`, 3 are `dfxtp_2` and 1 is `dfxtp_4`. Four flip-flops were resized: 3 × 1.2512 + 1 × 3.7536 = 7.5072 µm². This matches Sequential cell 2009.43 = 2001.92 + 7.51.
- CTS adds 10 clock buffers (9 `clkbuf_16`, 1 `clkbuf_8`, 238.98 µm²) and 6 clock inverters (56.30 µm²). 238.98 + 56.30 = 295.28 µm², which matches the CTS area step (12194 − 11899) within rounding.
- The 6 clock inverters are the cells `clkload1` to `clkload6`: 3 `clkinv_4`, 1 `clkinvlp_4`, 2 `inv_8`. They are the dummy loads that CTS inserts. A `clkinv_1` also exists in the final netlist, but it does not touch a clock net.
- CTS messages: root buffer `clkbuf_16`, 100 sinks on `clk`, 9 buffers created, 107 sinks after CTS (100 flip-flops + 7 dummy loads), tree level 3.

**Q3. Evidence.** `cts_evidence.txt`, `stage_evidence.txt`, `cell_type_report.txt`, `cell_evidence.txt`, `clock_net_cells.txt`.

**Q4. How much routing does the clock use?**
The clock adds 10 CLOCK nets: `clk`, `clknet_0_clk` and 8 leaf nets `clknet_3_0__leaf_clk` to `clknet_3_7__leaf_clk`. They use 1655.97 µm², which is 3.97% of the total wire length and 53.7% of the total increase (+3083.11 µm²). The other 46.3% is SIGNAL wire (+1427.14 µm²). `alu32_reg` also has 119 more routed nets than `alu32` (1508 against 1389) and a different synthesis netlist, so this increase cannot be assigned to the flip-flops alone.

**Q5. What changes in placement?**
`GPL-0102` (no slack, timing-driven off) does not appear in `3_3_place_gp.log`. `repair_design` runs two rounds: round 1 fixes 6 slew and 1 cap violation (6 resizes, 6 buffers, +104.200 µm²); round 2 fixes 1 cap violation (1 buffer, +51.970 µm²).

## 5. Variant: CTS clustering parameters

One variable at a time, each run stops at `cts`:

| Variant | Command line change | `4_1_cts.odb` md5 |
|---|---|---|
| `base` | none | 18806bc2... |
| `cts_cluster_size_5` | `CTS_CLUSTER_SIZE=5` | same |
| `cts_cluster_size_50` | `CTS_CLUSTER_SIZE=50` | same |
| `cts_cluster_diameter_10` | `CTS_CLUSTER_DIAMETER=10` | same |

The parameters reach the command: the logged command contains `-sink_clustering_size 5`, `-sink_clustering_size 50` or `-sink_clustering_max_diameter 10`. For the size variants, message `CTS-0090` ("Sinks will be clustered based on buffer max cap") is replaced by `CTS-0060` ("Register sinks will be clustered in groups of up to N"). The clock tree is identical in all four runs: 9 buffers, 107 sinks, 7 dummy loads, `CTS-0032` max number of sinks 15. The largest leaf net (`clknet_3_2__leaf_clk`) has 19 pins, which is 18 sinks plus its driver.

## 6. Open questions

1. Why is the combinational part of `alu32_reg` 75.072 µm² smaller than `alu32` alone? ABC is called with `-D 10.0` for `alu32_reg` and without `-D` for `alu32`, and the two `abc.constr` files are identical. Is `-D` the cause, and how does ABC use it?
2. `CTS-0207` reports 7 dummy loads but only 6 cells are named `clkload*`. Is the 7th dummy load the `clkbuf_8`, the only clock buffer that is not one of the 9 buffers created by `CTS-0018`?
3. Why do `CTS_CLUSTER_SIZE` (5 and 50) and `CTS_CLUSTER_DIAMETER` (10) not change the clock tree? What decides the tree for 100 sinks, and why do leaf nets have 18 sinks when groups of up to 5 are requested?
4. Does `CTS_BUF_DISTANCE`, or another CTS option, change the tree for this design?
5. Why does the odb wire length differ from the router total by a few µm?
