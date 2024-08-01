import os, sys

cur_path = os.getcwd()

os.system("mkdir build")
os.chdir("build")
cmd1 = "cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=../install/ .."
cmd2 = "make -j"
cmd3 = "make install"
os.system(cmd1)
os.system(cmd2)
os.system(cmd3)
os.chdir("../")
