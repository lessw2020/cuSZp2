import os, sys

os.system("mkdir double-datasets")
os.chdir("double-datasets")

# Get nwchem
cmd1 = "wget https://g-8d6b0.fd635.8443.data.globus.org/ds131.2/Data-Reduction-Repo/raw-data/NWChem/SDRBENCH-NWChem-dataset.tar.gz"
os.system(cmd1)
cmd2 = "tar -xvf SDRBENCH-NWChem-dataset.tar.gz"
os.system(cmd2)
cmd3 = "mv SDRBENCH-NWChem-dataset nwchem"
os.system(cmd3)
os.chdir("nwchem")
cmd4 = "rm -rf 631-tst.bin.d64 ccd-tst.bin.d64 readbin.cpp"
os.system(cmd4)
os.chdir("../")

cmd5 = "wget https://g-8d6b0.fd635.8443.data.globus.org/ds131.2/Data-Reduction-Repo/raw-data/S3D/SDRBENCH-S3D.tar.gz"
os.system(cmd5)
cmd6 = "tar -xvf SDRBENCH-S3D.tar.gz"
os.system(cmd6)
cmd7 = "mv SDRBENCH-S3D s3d"
os.system(cmd7)
os.chdir("s3d")
os.system("rm template.txt flist.txt")
os.chdir("../")

os.system("rm -rf *.tar.gz")
os.chdir("../")