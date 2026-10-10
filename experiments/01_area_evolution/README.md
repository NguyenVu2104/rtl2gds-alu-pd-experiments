# Experiment 1: Area Evolution (alu32)

Main question: **where does the design area go** in the RTL-to-GDS flow of `alu32`?

1. At which stage does the area change?
2. What does that stage add, remove, or resize?
3. What is the evidence?
4. If we turn off or reduce the cause, does the area go down?

## 1. Setup

**Design:** `alu32` is a combinational circuit (no Flip-flop, no clock). Inputs: `a`, `b` (32-bit) and `op` (4-bit). Output: `y` (32-bit). That is 100 I/O pins. Operations: ADD, SUB, SLT, SLTU, XOR, OR, AND, SLL, SRL, SRA. See `designs/alu32/`.

**Config** (`designs/alu32/config.mk`):

| Variable | Value |
|---|---|
| `PLATFORM` | `sky130hd` |
| `DESIGN_NAME` | `alu32` |
| `CORE_UTILIZATION` | 40 |
| `CORE_ASPECT_RATIO` | 1 |
| `CORE_MARGIN` | 2 |
| `PLACE_DENSITY` | 0.60 |

**Constraint** (`designs/alu32/constraint.sdc`): only `set_input_delay 0.0 [all_inputs]` and `set_output_delay 0.0 [all_outputs]`. There is no clock. So no path has a constraint (`No paths found`, `worst slack max INF`), and Timing is not analyzed in this report.

**Environment:** Ubuntu 22.04 (WSL). ORFS commit `d90873f47b79f343c6be15210ce398e1383c08d2`. OpenROAD `26Q2-1164-g08f67ee5ec` (12 threads). Yosys `0.65+71` (git `e56c6a954`). KLayout `0.30.7`. PDK Sky130 (`sky130hd`), Liberty file `sky130_fd_sc_hd__tt_025C_1v80.lib`.

**Reproducible:** running the baseline again in this repo gives the same checksum for `5_2_route.odb`: `b21c3c1c283928bcf0dd`. So the flow gives the same result on the same machine with the same number of threads.

**Data** (`data/`, taken from `work/`; `work/` is not pushed):

| File | Content |
|---|---|
| `stage_area_events.txt` | Lines with `Design area`, `Instance count`, `Number of instances`, `Inserted`, `Removed`, `Resized` from all logs (without `Removed fillers count`) |
| `synth_stat.txt` | Synthesis report |
| `3_3_buffer_events.txt` | Lines `RSZ-0026/0027/0028/0038/0039` and `GPL-0107` from `3_3_place_gp.log` |
| `cell_type_report.txt` | Cell type report at the end of the flow (`6_report.log`) |

## 2. Area metrics

The logs show several kinds of "area". Only **Design area** is used in the stage table.

| Metric | Source | Meaning |
|---|---|---|
| Chip area | `synth_stat.txt` | Sum of the standard-cell area after technology mapping. Taken from the Liberty file. It is not the die or floorplan area. |
| **Design area** | Line `Design area ... um^2 ...% utilization` (`report_design_area`) | Area of the instances in the design. It counts tapcells, buffers, and diodes. In this run it does **not** count fill cells (the value does not change after `filler_placement`). |
| Cell type report | `6_report.log` | Lists all cells by type, including fill cells. The total is equal to the core area. |
| `GPL-*` area | Global placement logs | Movable area plus *pin density area adjust* (a gpl feature, on by default), *Placed Cell Area*, *Final placement area* (includes routability inflation). These are numbers used inside the placer. They are **not the real area**. |

"Utilization" in the global placement log (`GPL-0019`) is also different from `report_design_area`. Example at 3_1: `GPL-0019` = 9804.374 / (21688.301 − 350.336) = 45.948% (area with pin density adjust, divided by free area). `report_design_area` gives 9158 / 21688.301 = 42%.

## 3. Area by stage

| Stage | Design area (µm²) | Instances | Event |
|---|---:|---:|---|
| synthesis | 8807.197 (Chip area) | 1258 | |
| 2_1 floorplan | 8807 (41%) | 1258 | Die and Core are defined. No cell added or removed. |
| 2_2 macro | 8807 | 1258 | No macro |
| 2_3 tapcell | 9158 (42%) | 1538 | +280 tapcells (+350.336) |
| 2_4 pdn | 9158 | 1538 | Only the power grid is added |
| 3_1 global place (skip IO) | 9158 | 1538 | |
| 3_2 IO placement | 9158 | 1538 | Only the pins are placed |
| 3_3 global place | **9856 (45%)** | 1555 | −97 synthesis buffers, +100 port buffers, `repair_design` |
| 3_4 resize | 9856 | 1555 | 0 resized, 0 buffers added |
| 3_5 detailed place | 9856 | 1555 | Cells only move |
| 4_1 cts | 9856 | 1555 | No clock net |
| 5_1 global route | 9856 | 1555 | |
| 5_2 detail route | **9861 (45%)** | 1557 | +2 diodes (+5.00) |
| 5_3 fillcell | 9861 | 1557 (+2235 fill) | Fill cells are not counted in Design area |

Total: 8807.197 → 9860.71 µm² (+1053.513 µm², +11.96%). Where it comes from: tapcells +350.336 (33.3%), stage 3_3 +698.167 (66.3%), diodes +5.01 (0.5%).

Instance count in 3_3: 1538 − 97 + 68 + 32 = 1541. Then +9 (`repair_design`) = 1550. Then +14 − 9 (rebuffer) = 1555. The log of 3_4 says `Instance count before 1555`, which matches.

## 4. Stage details

### Synthesis

`Chip area for module '\alu32': 8807.196800` and `Number of instances: 1258`. The area comes from the cell area in the Liberty file (technology mapping). It is not the die area.

### 2_1 floorplan

```
IFP-0107 Defining die area using utilization: 40.00% and aspect ratio: 1.
IFP-0028 Core area lower left (2.000, 2.000) snapped to (2.300, 2.720).
IFP-0001 Added 54 rows of 321 site unithd.
IFP-0100 Die BBox:  (0.000 0.000) (152.385 152.385) um
IFP-0101 Core BBox: (2.300 2.720) (149.960 149.600) um
IFP-0102 Core area: 21688.301 um^2
IFP-0103 Total instances area: 8807.197 um^2
IFP-0104 Effective utilization: 0.406
IFP-0105 Number of instances: 1258
```

The number of instances is 1258 before and after Floorplan (`number instances in verilog is 1258`, `IFP-0105`), and the area stays the same. Floorplan changes the geometry, not the number of cells.

Every number can be traced to a formula:

- Target core side = √(8807.197 / 0.40) = 148.385. Die = core + 2 × `CORE_MARGIN` = 148.385 + 4 = 152.385. The margin is added outside the core. A bigger `CORE_MARGIN` makes the die bigger and keeps the core the same.
- The real core is snapped to the site grid (0.46 µm) and the row grid (2.72 µm): 321 sites × 0.46 = 147.66 µm and 54 rows × 2.72 = 146.88 µm. Core area = 147.66 × 146.88 = 21688.3 µm².
- Effective utilization = 8807.197 / 21688.301 = 0.406. It is not exactly the target 0.40 because of the snapping.

Geometry means the physical size and position of things: Die (152.385 × 152.385 µm), Core (147.66 × 146.88 µm), rows, tracks, power grid. Changing geometry does not have to change the number of logic cells.

### 2_2 macro

`No macros found: Skipping macro_placement`.

### 2_3 tapcell

`TAP-0005 Inserted 280 tapcells`. Area goes from 8807 to 9158 µm² (about +351 µm²).

Hypothesis: one tapcell has an area of about 351 / 280 = 1.25 µm². Check in the LEF file `sky130_fd_sc_hd_merged.lef`: `sky130_fd_sc_hd__tapvpwrvgnd_1` has `CLASS CORE WELLTAP` and `SIZE 0.46 BY 2.72`. So its area is 0.46 × 2.72 = 1.2512 µm². Then 280 × 1.2512 = 350.336, which is `GPL-0017` (Fixed instances area). Also 8807.197 + 350.336 = 9157.533 = `GPL-0037`. The hypothesis is confirmed.

### 2_4 pdn

`PDN-0001 Inserting grid`. Design area stays 9158 µm². The PDN adds metal power grid, not standard-cell instances.

### 3_1 global place (skip IO)

This stage places the standard cells but ignores the IO ports when it computes wirelength. It gives a first position for the cells, which 3_2 uses.

```
GPL-0036 Movable instances area: 8807.197    (from synthesis)
GPL-0017 Fixed instances area:    350.336    (280 tapcells)
GPL-0037 Total instances area:   9157.533
GPL-0035 Pin density area adjust: 997.178
GPL-0018 Movable instances area:  9804.374   (= 8807.197 + 997.178)
```

No cell is added. `Placed Cell Area 9804.3744` is an *effective area* for the placement algorithm (it includes the pin density adjust). It is not the real area.

### 3_2 IO placement

`io_placement.tcl` loads `3_1_place_gp_skip_io.odb`, runs `place_pins`, and writes `3_2_place_iop.odb`. (If `FLOORPLAN_DEF`, `FOOTPRINT`, or `FOOTPRINT_TCL` is set, it skips `place_pins` and only copies the file.)

`place_pins` puts the pins on the die edge to reduce the length of the nets. So it needs the cell positions first. This is why 3_1 (ignores IO) comes before 3_2, and 3_3 (uses IO) comes after. Floorplan only defines the die, core, and rows.

`PPL-0002` shows 100 I/O pins (32 + 32 + 4 + 32). This stage places **pins**. It does not add I/O cells or pads (those are for chip-level designs with a pad ring). The area does not change.

### 3_3 global place: the biggest area increase (+698 µm²)

Global placement finds a position for each movable cell. But in this flow, `global_place.tcl` also changes the netlist:

- `remove_buffers` (line 10): `RSZ-0026 Removed 97 buffers`.
- `buffer_ports` (lines 18 to 20, controlled by `DONT_BUFFER_PORTS`): `RSZ-0027` adds 68 input buffers and `RSZ-0028` adds 32 output buffers. All are `sky130_fd_sc_hd__clkdlybuf4s50_1`.
- `repair_design` inside the timing-driven iteration (`GPL-0100`): `RSZ-0034` finds 7 slew violations and `RSZ-0036` finds 4 capacitance violations. `RSZ-0039` resizes 7 instances. `RSZ-0038` inserts 9 buffers in 7 nets. Then a rebuffer step removes 9 and inserts 14 buffers.

Area change in this stage: 9855.70 − 9157.533 = **698.167 µm²**.

| Source | Change (µm²) | Share |
|---|---:|---:|
| Remove 97 synthesis buffers, add 100 port buffers (movable area 8807.197 → 9378.995) | +571.798 | ~82% |
| `repair_design` (`GPL-0107`: 121.984, +1.16%) | +121.984 | ~17% |
| Not explained | +4.385 | ~0.6% |

How the +571.798 is checked:

- The 97 synthesis buffers are in `synth_stat.txt`: 12 `buf_1` + 15 `buf_2` + 4 `buf_4` + 4 `buf_6` + 61 `clkbuf_1` + 1 `clkbuf_2` = 97 cells. Their total area is 429.162 µm².
- `clkdlybuf4s50_1` has an area of 10.0096 µm² in the Liberty file. So 100 × 10.0096 = 1000.96 µm².
- 1000.96 − 429.162 = 571.798 = 9378.995 − 8807.197. The numbers match to three decimal places.

The Cell type report at the end of the flow shows Timing Repair Buffer = 114 = 100 port buffers + 9 + (14 − 9). This is consistent.

Notes:

- There is no constraint, so `GPL-0106` shows worst slack 1e+30 and `GPL-0102` says "no slacks found, Timing-driven mode disabled". But the changes made by `repair_design` stay in the netlist (Design area after this stage is 9856).
- `Final placement area 11607.35 (+10.16%)` is not the real area. It is the Original area 10536.88 plus the *routability artificial inflation* 825.26 (`GPL-1012`) plus other parts that do not add up in a simple way. It is a number used inside the placer. The real area after 3_3 is 9856.

### 3_4 resize

`repair_design -verbose -match_cell_footprint` runs after `estimate_parasitics -placement`. It looks for nets with slew, capacitance, or fanout violations, and it can insert buffers or resize cells. Result: Resized 0, Buffers 0, `Instance count before 1555, after 1555`, Design area 9856.

Stage 3_3 already fixed the 7 slew and 4 capacitance violations, so 3_4 has nothing left to fix (`max slew/cap violation count 0` in `3_resizer.rpt`). The column `Remaining` (1442 → 0) is the number of nets that were checked (1428 + 9 + 5 = 1442). It is not the number of nets that were fixed.

### 3_5 detailed placement

`detailed_placement` moves cells to legal positions. It does not add, remove, or resize cells, so the area does not change.

- Instances area is 9855.70 µm² before and after (`DPL-0006`).
- 1275 cells were placed legally (1555 − 280 tapcells).

### 4_1 cts

The design has no clock, so CTS has nothing to build:

```
CTS-0083 No clock nets have been found.
CTS-0008 TritonCTS found 0 clock nets.
CTS-0082 No valid clock nets in the design.
RSZ-0098 No setup violations found
RSZ-0033 No hold violations found.
```

The area does not change for two separate reasons:

1. There is no clock net, so there is no clock tree and no clock buffer.
2. `repair_timing` finds no violation, because no path has a constraint.

`detailed_placement` runs twice in this stage with displacement 0.0, so nothing moves. The log also prints `CTS-0050` and `CTS-0051` (`clkbuf_16` as root and sink buffer), but this buffer is not used.

### 5_1 global route

Design area stays 9856 µm².

### 5_2 detail route (+5 µm²)

`detail_route.tcl` (lines 54 to 62) runs `detailed_route`, then `repair_antennas`. It runs `detailed_route` again only if `repair_antennas` returns true.

What happened in our run:

1. The first `detailed_route` finished.
2. The antenna check found 2 violations (`GRT-0012`).
3. 2 diodes were inserted (`GRT-0015`). In `6_final.def` they are 2 instances of `sky130_fd_sc_hd__diode_2`.
4. `detailed_route` ran a second time.
5. The final result is 0 DRC violations and 0 antenna violations (`DRT-0199`, `ANT-0001`, `ANT-0002`).

An antenna violation means a long metal wire can collect charge during manufacturing and damage a gate. A diode gives the charge a path to the substrate.

Area: the Cell type report shows Antenna cell = 2, area 5.00 µm². Instances area goes from 9855.70 to 9860.71 µm² (+5.01, `DPL-0006`). This is the only area change in routing.

### 5_3 fillcell

`filler_placement` places 2235 fill cells (`fill_1`, `fill_2`, `fill_4`, `fill_8`, `DPL-0001`). Design area stays 9861 µm² right after. So in this OpenROAD version, `report_design_area` does not count fill cells. The Cell type report counts them:

```
Cell type report:                       Count       Area
  Fill cell                              2235   11827.59
  Tap cell                                280     350.34
  Antenna cell                              2       5.00
  Timing Repair Buffer                    114    1093.55
  Inverter                                 91     341.58
  Multi-Input combinational cell         1070    8070.24
  Total                                  3792   21688.30
```

Checks:

- 350.34 + 5.00 + 1093.55 + 341.58 + 8070.24 = 9860.71. This is the same as Instances area in `DPL-0006`.
- Fill area = 21688.30 − 9860.71 = 11827.59. The total is equal to the core area, so fill cells cover all the empty space.
- Count: 3792 − 2235 = 1557 = 1555 + 2 diodes.

In the LEF file, `fill_1` has `CLASS CORE SPACER` and the tapcell has `CLASS CORE WELLTAP`. Tapcells are counted in Design area. Fill cells are not.

## 5. Conclusion (Q1 to Q3)

**Q1: At which stage does the area change?** At three stages: 2_3 tapcell (+350.336), 3_3 global place (+698.167, +7.6%), and 5_2 detail route (+5.01). All other stages keep the same Design area: Floorplan, PDN, IO placement, resize, detailed placement, CTS, global route, and fill. The total change is from 8807.197 to 9860.71 µm² (+1053.513 µm², +11.96%).

**Q2: What is added, removed, or resized?**

| Stage | Change | Reason |
|---|---|---|
| 2_3 | +280 tapcells | Well-tap cells placed on a grid in the core |
| 3_3 | −97 synthesis buffers, +100 `clkdlybuf4s50_1` port buffers | `remove_buffers`, `buffer_ports` |
| 3_3 | 7 cells resized, +9 buffers, rebuffer (−9, +14) | `repair_design` fixes 7 slew and 4 capacitance violations |
| 5_2 | +2 `sky130_fd_sc_hd__diode_2` | Antenna repair after detail route |
| 4_1, 5_3 | No increase of Design area | No clock net; fill cells are not counted |

**Q3: What is the evidence?** The numbers match in a chain. Tapcell: 280 × 1.2512 = 350.336, equal to `GPL-0017`. Stage 3_3: the 97 buffers in `synth_stat` have 429.162 µm², 100 × 10.0096 = 1000.96 µm², and the difference 571.798 is equal to the change of the movable area. The instance count goes 1538 → 1541 → 1555 and matches 3_4. Timing Repair Buffer 114 = 100 + 9 + 5. Stage 5_2: Antenna cell 5.00 µm² matches `DPL-0006` (+5.01). Fill: 11827.59 = core area − Design area. The files are in `data/`.

**Lesson:** physical implementation changes the netlist by itself (buffers, resizing, diodes), so the cell count and the area change after synthesis. Before you draw a conclusion, you must separate Chip area, Design area, the Cell type report, and the "area" numbers used inside the placer.

## 6. Open questions

1. **What adds the last 4.385 µm² in 3_3?** The port buffers and the removed buffers explain +571.798 µm². `repair_design` explains +121.984 µm². Together this is 693.782 µm², but the real change is 698.167 µm². The log lines we have do not explain the last 4.385 µm².

2. **Why does `report_design_area` skip fill cells?** Fill cells are `CORE SPACER` and tapcells are `CORE WELLTAP`. Tapcells are counted and fill cells are not. Does OpenROAD skip cells by class? We did not read the code, so we only know what the log shows.

## 7. Q4: What happens if we remove the cause?

We changed one thing at a time and compared with the baseline (`FLOW_VARIANT=base`).

### Test A: no port buffers

Variant `no_port_buffers`: `DONT_BUFFER_PORTS=1`. We ran the flow only up to `place` and compared with the baseline after stage 3_3.

`DONT_BUFFER_PORTS=1` only stops `buffer_ports`, which adds the port buffers. `repair_design` is a different step. It can still insert buffers to fix slew and capacitance violations, so the line `RSZ-0038 Inserted 7 buffers in 4 nets` is not a port buffer.

| | Design area (µm²) |
|---|---:|
| baseline | 9856 |
| `no_port_buffers` | 8830 |
| Change | about −1026 (−10.4%) |

The log of the variant shows `RSZ-0026 Removed 97 buffers` and no `RSZ-0027` or `RSZ-0028` line. So the 97 synthesis buffers are removed and no port buffer is added.

The drop comes from two parts:

- The 100 port buffers are not added: −1000.96 µm² (100 × 10.0096).
- `repair_design` adds less area: 98.951 µm² instead of 121.984 µm² (`GPL-0107`), which is 23.033 µm² less.

`repair_design` in stage 3_3:

| | baseline | `no_port_buffers` |
|---|---:|---:|
| Slew violations (`RSZ-0034`) | 7 | 4 |
| Capacitance violations (`RSZ-0036`) | 4 | 4 |
| Instances resized (`RSZ-0039`) | 7 | 4 |
| Buffers inserted (`RSZ-0038`) | 9 in 7 nets | 7 in 4 nets |
| Area added (`GPL-0107`) | 121.984 µm² | 98.951 µm² |

The result is also lower than the area before 3_3 (9158 µm²). 9157.533 − 429.162 (97 synthesis buffers removed) + 98.951 = 8827.322, and the log says 8830. This is a gap of about 2 to 3 µm², similar to the 4.385 µm² in the baseline.

Answer for Q4: the port buffers are the main cause of the area increase in stage 3_3. Without them the area is about 10.4% lower.

We ran the flow only up to placement. So we do not know if routing becomes harder without port buffers. CTS is not affected, because the design has no clock.

### Test B: ABC area script

Variant `abc_area`: `ABC_AREA=1`. We ran only `synth`. This option makes Yosys use `abc_area.script` instead of `abc_speed.script`. ABC still runs; only the script is different.

| | baseline (`abc_speed.script`) | `abc_area` (`abc_area.script`) |
|---|---:|---:|
| Chip area (µm²) | 8807.1968 | 9482.8448 |
| Cells | 1258 | 1895 |
| Buffers (cells / µm²) | 97 / 429.162 | 85 / 470.451 |
| `nand2_1` | 112 | 557 |
| `nand3_1` | 18 | 439 |
| `inv_1` | 88 | 246 |
| `mux4_2` | 43 | 0 |
| `mux2i_1` | 50 | 0 |

We expected the area to go down. It went up by 675.648 µm² (+7.67%).

- The area script uses 637 more cells (+50.6%).
- Buffers are not the cause. The number and area of buffers are about the same.
- The area script builds the logic from many simple NAND, NOR, and inverter cells. It almost does not use complex cells (`mux4_2`, `mux2i_1`, `a2111oi`).
- The `ha_1` and `fa_1` cells are the same in both runs.
- The two scripts use different ABC commands. The speed script runs several rounds of `&st`, `&syn2`, `&if -g -K 6`, `&synch2`, and `&nf`. The area script runs `strash`, `dch`, and `map -B 0.9`.

### Open questions from Q4

1. Why are there 3 fewer slew violations (4 instead of 7) when the ports have no buffers?
2. What does the design lose without port buffers? In this run we see no extra violations. But the SDC has no `set_driving_cell` and no `set_load`, so the ports look ideal to the tool.
3. Why does the area script give more area? Which ABC command makes it avoid the complex cells?