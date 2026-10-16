import re
import odb

project_directory = "/home/vu/PD_projects/rtl2gds-alu-pd-experiments"
variant_names = ["base", "period_4p374", "period_3p888", "period_3p402"]
stage_files = ["3_3_place_gp.odb", "4_1_cts.odb"]


def read_instances(odb_path):
    database = odb.dbDatabase.create()
    odb.read_db(database, odb_path)
    block = database.getChip().getBlock()
    prefix_counts = {}
    master_counts = {}
    for instance in block.getInsts():
        instance_name = instance.getName()
        master_name = instance.getMaster().getName()
        master_counts[master_name] = master_counts.get(master_name, 0) + 1
        match = re.match(r"^([A-Za-z]+(?:_[A-Za-z]+)*_?)[0-9]+$", instance_name)
        if match:
            prefix = match.group(1)
        elif instance_name.startswith("_") and instance_name.endswith("_"):
            prefix = "(yosys _N_)"
        else:
            prefix = "(other)"
        prefix_counts[prefix] = prefix_counts.get(prefix, 0) + 1
    return prefix_counts, master_counts


for stage_file in stage_files:
    print("=== stage file:", stage_file)
    results = {}
    for variant_name in variant_names:
        odb_path = project_directory + "/work/results/sky130hd/alu32_reg/" + variant_name + "/" + stage_file
        results[variant_name] = read_instances(odb_path)
    for variant_name in variant_names:
        prefix_counts, master_counts = results[variant_name]
        print("--- variant:", variant_name, "total instances:", sum(master_counts.values()))
        for prefix, count in sorted(prefix_counts.items()):
            print("    prefix", prefix, count)
    base_masters = results["base"][1]
    for variant_name in variant_names[1:]:
        variant_masters = results[variant_name][1]
        print("--- master count changes, base ->", variant_name)
        for master_name in sorted(set(base_masters) | set(variant_masters)):
            count_before = base_masters.get(master_name, 0)
            count_after = variant_masters.get(master_name, 0)
            if count_before != count_after:
                print("   ", master_name, count_before, "->", count_after)
