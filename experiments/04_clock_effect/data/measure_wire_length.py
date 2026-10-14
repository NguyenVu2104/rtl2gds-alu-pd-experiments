import odb

def measure(odb_path, label):
    design_database = odb.dbDatabase.create()
    odb.read_db(design_database, odb_path)
    block = design_database.getChip().getBlock()
    database_units_per_micron = block.getDbUnitsPerMicron()
    length_by_signal_type = {}
    count_by_signal_type = {}
    clock_net_rows = []
    for net in block.getNets():
        wire = net.getWire()
        if wire is None:
            continue
        length_microns = wire.getLength() / database_units_per_micron
        signal_type = str(net.getSigType())
        length_by_signal_type[signal_type] = length_by_signal_type.get(signal_type, 0.0) + length_microns
        count_by_signal_type[signal_type] = count_by_signal_type.get(signal_type, 0) + 1
        if signal_type == "CLOCK":
            clock_net_rows.append((net.getName(), len(net.getITerms()), round(length_microns, 2)))
    print("---", label, "| dbu per micron:", database_units_per_micron)
    for signal_type in length_by_signal_type:
        print(signal_type, "nets with wire:", count_by_signal_type[signal_type], "total length (um):", round(length_by_signal_type[signal_type], 2))
    print("all nets total length (um):", round(sum(length_by_signal_type.values()), 2))
    for row in clock_net_rows:
        print("clock net:", row)

measure("/home/vu/PD_projects/rtl2gds-alu-pd-experiments/work/results/sky130hd/alu32_reg/base/5_route.odb", "alu32_reg (router reported 41709 um)")
measure("/home/vu/PD_projects/rtl2gds-alu-pd-experiments/work/results/sky130hd/alu32/base/5_route.odb", "alu32 (router reported 38634 um)")
