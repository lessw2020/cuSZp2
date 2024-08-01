import os, sys

folder_list = ["rel-1e-2-com", 
               "rel-1e-2-dec",
               "rel-1e-3-com",
               "rel-1e-3-dec",
               "rel-1e-4-com",
               "rel-1e-4-dec"]

for folder in folder_list:
    os.chdir(folder)

    os.system("bash run.sh")
    os.system("mv *.png ../")

    os.chdir("../")