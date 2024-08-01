import os, sys

dataset_list = ["cesm_atm", "hacc", "scale", "qmcpack", "nyx", "jetin", "miranda", "syntruss"]
cesm_atm_url = "https://g-8d6b0.fd635.8443.data.globus.org/ds131.2/Data-Reduction-Repo/raw-data/CESM-ATM/SDRBENCH-CESM-ATM-26x1800x3600.tar.gz"
hacc_url = "https://g-8d6b0.fd635.8443.data.globus.org/ds131.2/Data-Reduction-Repo/raw-data/EXASKY/HACC/EXASKY-HACC-data-big-size.tar.gz"
scale_url = "https://g-8d6b0.fd635.8443.data.globus.org/ds131.2/Data-Reduction-Repo/raw-data/SCALE_LETKF/SDRBENCH-SCALE-98x1200x1200.tar.gz"
qmcpack_url = "https://g-8d6b0.fd635.8443.data.globus.org/ds131.2/Data-Reduction-Repo/raw-data/QMCPack/SDRBENCH-QMCPack.tar.gz"
nyx_url = "https://g-8d6b0.fd635.8443.data.globus.org/ds131.2/Data-Reduction-Repo/raw-data/EXASKY/NYX/SDRBENCH-EXASKY-NYX-512x512x512.tar.gz"
jetin_url = "https://klacansky.com/open-scivis-datasets/jicf_q/jicf_q_1408x1080x1100_float32.raw"
miranda_url = "https://klacansky.com/open-scivis-datasets/miranda/miranda_1024x1024x1024_float32.raw"
syntruss_url = "https://klacansky.com/open-scivis-datasets/synthetic_truss_with_five_defects/synthetic_truss_with_five_defects_1200x1200x1200_float32.raw"

os.system("mkdir dataset")
os.chdir("dataset")

cmd1 = "wget " + cesm_atm_url
cmd2 = "wget " + hacc_url
cmd3 = "wget " + scale_url
cmd4 = "wget " + qmcpack_url
cmd5 = "wget " + nyx_url
cmd6 = "wget " + jetin_url
cmd7 = "wget " + miranda_url
cmd8 = "wget " + syntruss_url
os.system(cmd1)
os.system(cmd2)
os.system(cmd3)
os.system(cmd4)
os.system(cmd5)
os.system(cmd6)
os.system(cmd7)
os.system(cmd8)

os.system("tar -xvf SDRBENCH-CESM-ATM-26x1800x3600.tar.gz")
os.system("tar -xvf EXASKY-HACC-data-big-size.tar.gz")
os.system("tar -xvf SDRBENCH-SCALE-98x1200x1200.tar.gz")
os.system("tar -xvf SDRBENCH-QMCPack.tar.gz")
os.system("tar -xvf SDRBENCH-EXASKY-NYX-512x512x512.tar.gz")
os.system("rm -rf *.tar.gz")

os.system("mv SDRBENCH-CESM-ATM-26x1800x3600 cesm_atm")
os.system("mv 1billionparticles_onesnapshot hacc")
os.system("mv SDRBENCH-SCALE_98x1200x1200 scale")
os.system("mkdir qmcpack")
os.system("mv dataset/115x69x69x288/einspline_115_69_69_288.f32 qmcpack/")
os.system("mv dataset/288x115x69x69/einspline_288_115_69_69.pre.f32 qmcpack/")
os.system("rm -rf dataset")
os.system("mv SDRBENCH-EXASKY-NYX-512x512x512 nyx")
os.system("rm nyx/template_data.txt")
os.system("mkdir jetin && mv jicf_q_1408x1080x1100_float32.raw jetin/")
os.system("mkdir miranda && mv miranda_1024x1024x1024_float32.raw miranda/")
os.system("mkdir syntruss && mv synthetic_truss_with_five_defects_1200x1200x1200_float32.raw syntruss/")

os.chdir("../")

