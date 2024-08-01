import os, sys
import subprocess

error_bound = sys.argv[1]
dataset_list = ["cesm_atm", "hacc", "scale", "qmcpack", "nyx", "jetin", "miranda", "syntruss"]
cur_path = os.getcwd()
gsz_p_bin = cur_path + "/install/bin/gsz_p"
gsz_o_bin = cur_path + "/install/bin/gsz_o"
dataset_base = cur_path + "/../dataset/"

def output_process(raw_string):
    cmp = 0.0
    dec = 0.0
    cr = 0.0
    raw_string1 = raw_string.split('\n')
    for item in raw_string1:
        if("GSZ compression   end-to-end speed: " in item):
            cmp = float(item.replace("GSZ compression   end-to-end speed: ", "").replace(" GB/s", ""))
        elif("GSZ decompression end-to-end speed: " in item):
            dec = float(item.replace("GSZ decompression end-to-end speed: ", "").replace(" GB/s", ""))
        elif("GSZ compression ratio: " in item):
            cr = float(item.replace("GSZ compression ratio: ", ""))
    return cmp, dec, cr

for dataset in dataset_list:
    temp_dataset_path = dataset_base + dataset + "/"
    cur_dataset_list = os.listdir(temp_dataset_path)
    num_of_field = len(cur_dataset_list)

    gszp_cmp_throughput_total = 0.0
    gszp_dec_throughput_total = 0.0
    gszp_compression_ratio_list = []

    gszo_cmp_throughput_total = 0.0
    gszo_dec_throughput_total = 0.0
    gszo_compression_ratio_list = []

    for field in cur_dataset_list:
        target_field = temp_dataset_path + field
        gsz_p_cmd = gsz_p_bin + ' ' + target_field + ' ' + error_bound
        gsz_o_cmd = gsz_o_bin + ' ' + target_field + ' ' + error_bound

        gsz_p_output = subprocess.getoutput(gsz_p_cmd)
        gsz_o_output = subprocess.getoutput(gsz_o_cmd)

        gsz_p_cmp_throughput_temp, gsz_p_dec_throughput_temp, gsz_p_cr_temp = output_process(gsz_p_output)
        gsz_o_cmp_throughput_temp, gsz_o_dec_throughput_temp, gsz_o_cr_temp = output_process(gsz_o_output)

        gszp_cmp_throughput_total += gsz_p_cmp_throughput_temp
        gszp_dec_throughput_total += gsz_p_dec_throughput_temp
        gszp_compression_ratio_list.append(gsz_p_cr_temp)

        gszo_cmp_throughput_total += gsz_o_cmp_throughput_temp
        gszo_dec_throughput_total += gsz_o_dec_throughput_temp
        gszo_compression_ratio_list.append(gsz_o_cr_temp)
    
    gszp_cmp_throughput_total = gszp_cmp_throughput_total/num_of_field
    gszp_dec_throughput_total = gszp_dec_throughput_total/num_of_field
    gszp_cr_max = max(gszp_compression_ratio_list)
    gszp_cr_min = min(gszp_compression_ratio_list)
    gszp_cr_avg = sum(gszp_compression_ratio_list)/len(gszp_compression_ratio_list)

    gszo_cmp_throughput_total = gszo_cmp_throughput_total/num_of_field
    gszo_dec_throughput_total = gszo_dec_throughput_total/num_of_field
    gszo_cr_max = max(gszo_compression_ratio_list)
    gszo_cr_min = min(gszo_compression_ratio_list)
    gszo_cr_avg = sum(gszo_compression_ratio_list)/len(gszo_compression_ratio_list)

    print("====================================================================")
    print("Done with Execution GSZ-P and GSZ-O on \033[31m" + dataset + "\033[0m under \033[31m" + error_bound + "\033[0m")
    print("GSZ-P   compression throughput: " + str(gszp_cmp_throughput_total) + " GB/s")
    print("GSZ-P decompression throughput: " + str(gszp_dec_throughput_total) + " GB/s")
    print("GSZ-P    max compression ratio: " + str(gszp_cr_max))
    print("GSZ-P    min compression ratio: " + str(gszp_cr_min))
    print("GSZ-P    avg compression ratio: " + str(gszp_cr_avg))
    print()
    print("GSZ-O   compression throughput: " + str(gszo_cmp_throughput_total) + " GB/s")
    print("GSZ-O decompression throughput: " + str(gszo_dec_throughput_total) + " GB/s")
    print("GSZ-O    max compression ratio: " + str(gszo_cr_max))
    print("GSZ-O    min compression ratio: " + str(gszo_cr_min))
    print("GSZ-O    avg compression ratio: " + str(gszo_cr_avg))
    print("====================================================================")
    print()