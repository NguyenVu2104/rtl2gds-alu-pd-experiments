import odb

design_database = odb.dbDatabase.create()
odb.read_db(design_database, "/home/vu/PD_projects/rtl2gds-alu-pd-experiments/work/results/sky130hd/alu32_reg/base/5_route.odb")
block = design_database.getChip().getBlock()

count_by_master = {}
inverter_instances = []
for instance in block.getInsts():
    touches_clock_net = False
    for instance_terminal in instance.getITerms():
        net = instance_terminal.getNet()
        if net is not None and str(net.getSigType()) == "CLOCK":
            touches_clock_net = True
            break
    if not touches_clock_net:
        continue
    master_name = instance.getMaster().getName()
    count_by_master[master_name] = count_by_master.get(master_name, 0) + 1
    if "inv" in master_name:
        inverter_instances.append((instance.getName(), master_name))

print("cells touching a CLOCK net, by master:")
for master_name in sorted(count_by_master):
    print(count_by_master[master_name], master_name)
print("inverter-like cells touching a CLOCK net:", len(inverter_instances))
for row in inverter_instances:
    print(row)
