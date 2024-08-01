# SC24-cuSZp2

## 0. Introduction
cuSZp2 (a.k.a. name as GSZ in paper submission) is a lossy error-bounded compression library specifically for NVIDIA GPUs for compression of floating-point data. This repository is used for AD-AE process for SC'24 conference. The official and final version of cuSZp2 will be updated into cuSZp repository [\[LINK\]](https://github.com/szcompressor/cuSZp) in the future. **For simplicity, we will still use the name GSZ in this repository, to align what is reported in the submission version.**

Before we start the AD/AE process, here are some regular QAs:
- **Information about lossy compressor and HPC?**
  - HPC simulation, such as quantum simulation or climate simulation, turns to produce very large dataset. While lossless compression has limited compression ratio, lossy compression can achieve very high compression ratio with user tolerable errors.
- **How does lossy compressor work?**
  - There are two phases of a lossy compressor: **Compression** and **Decompression**. Compression takes an HPC dataset (e.g. vx.f32 from HACC dataset) as input to compress and generates the compressed HPC dataset as output. Meanwhile, decompression takes an compressed dataset as input and decomressed it to reconstructed (we can also call it decompressed) dataset as output.
- **What is GPU lossy compressor?**
  - GPU lossy compressor indicates the compression and decompression computations are executed in GPU. Why? Because GPU can do this much faster.
- **Why we propose GSZ and how to evaluate it?**
  - Existing GPU compressor is slow, so we propose an extremely fast GPU compressor - GSZ. **As a result, the main contribution of GSZ is its throughput (GB/s)**, which can be understood as data processing speed. But the improved speed cannot be sacrifised from other metrics like compression ratio, **so another important metric is compression ratio, computed by** $OriDataSize/CmpDataSize$.

## 1. Dataset Download and Information
Before configuration, this section explains where can we get the evaluated HPC dataset (i.e. input of GSZ compressor) in paper and how to use them.

The table below includes metadata of the 9 HPC datasets are used in paper. For Suite information, SDRBench can be found here [LINK](https://sdrbench.github.io/), and Open-SciVis can be found here [LINK](https://klacansky.com/open-scivis-datasets/).
| Dataset  | Suite      |  #Fields | Download Link      |
| -------- | -------    | -------  | -------   |
| CESM-ATM | SDRBench   |    33    | [Link](https://g-8d6b0.fd635.8443.data.globus.org/ds131.2/Data-Reduction-Repo/raw-data/CESM-ATM/SDRBENCH-CESM-ATM-26x1800x3600.tar.gz)  |
| HACC     | SDRBench   |    6     | [Link](https://g-8d6b0.fd635.8443.data.globus.org/ds131.2/Data-Reduction-Repo/raw-data/EXASKY/HACC/EXASKY-HACC-data-big-size.tar.gz)    |
| RTM      | SDRBench   |    3     | Excluded due to confidential issue.     |
| Scale    | SDRBench   |    12    | [Link](https://g-8d6b0.fd635.8443.data.globus.org/ds131.2/Data-Reduction-Repo/raw-data/SCALE_LETKF/SDRBENCH-SCALE-98x1200x1200.tar.gz) |
| QMCPack  | SDRBench   |    2     | [Link](https://g-8d6b0.fd635.8443.data.globus.org/ds131.2/Data-Reduction-Repo/raw-data/QMCPack/SDRBENCH-QMCPack.tar.gz)  |
| NYX      | SDRBench   |    6     |  [Link](https://g-8d6b0.fd635.8443.data.globus.org/ds131.2/Data-Reduction-Repo/raw-data/EXASKY/NYX/SDRBENCH-EXASKY-NYX-512x512x512.tar.gz)      |
| JetIn    | Open-SciVis|    1     | [Link](https://klacansky.com/open-scivis-datasets/jicf_q/jicf_q_1408x1080x1100_float32.raw)  |
| Miranda  | Open-SciVis|    1     | [Link](https://klacansky.com/open-scivis-datasets/miranda/miranda_1024x1024x1024_float32.raw)  |
| SynTruss | Open-SciVis|    1     | [Link](https://klacansky.com/open-scivis-datasets/synthetic_truss_with_five_defects/synthetic_truss_with_five_defects_1200x1200x1200_float32.raw) |

What does "#Fields" mean here? It means how many seperated snapshots are there in one dataset. We use HACC dataset as an example to explain this.
```shell
# Step 1: Download dataset from the link above.
wget https://g-8d6b0.fd635.8443.data.globus.org/ds131.2/Data-Reduction-Repo/raw-data/EXASKY/HACC/EXASKY-HACC-data-big-size.tar.gz

# Step 2: Decompressed the downloaded package into a folder.
tar -xvf EXASKY-HACC-data-big-size.tar.gz

# Step 3: Change directory into this folder and check.
cd ./1billionparticles_onesnapshot
ls
vx.f32  vy.f32  vz.f32  xx.f32  yy.f32  zz.f32
```
We can see that, there are 6 files (e.g. ```vx.f32```) generated and each of them may represent one specific snapshot in the given HPC environment.
The "6" here means 6 fields.
Each field will be the input for a compressor, one example execution command can be shown as below.
```shell
./example_compression vx.f32
```

When we evaluate GSZ compressor in the paper, we usually mention the compression or decompression throughput on HACC dataset (or some other datasets): **that means executing compression or decompression for each of the field in this dataset and gets its average**.
However, to be honest, the compression or decompression throughput turns out to be similar for one compressor within one dataset - the reason is that the data patterns in one dataset are likely to maintain consistent across different fields.

## 2. Align Figures in Paper with Code in This Repo
In this section, we will explain the most important several figures in paper (the submission version) and align which folder in this repo can reproduce them.
- **Figure 14: Throughput Evaluation**
  - Folder for Reproducing: ```0-main-results```
- Table III: Compression Ratio Evaluation
  - Folder for Reproducing: ```0-main-results```
- Figure 19: Throughput for Double-Precision Support
  - Folder for Reproducing: ```1-double-precision```
- Table V: Compression Ratio for Double-Precision Support
  - Folder for Reproducing: ```1-double-precision```
- Figure 20: Throughput for Random Access Support
  - Folder for Reproducing: ```2-random-access```
- Figure 21: Throughput for Other NVIDA GPUs
  - Folder for Reproducing: ```0-main-results```


## 3. Reproducing Experimental Results
In this section, we will guide how to reproduce the results shown in Figure/Table in paper step by step.
We first explain the prerequisites for this section. And for each folder, we will explain:
- How to install.
- How to execute.
- How to understand the output.
### 3.1 Prerequisite
- A Linux Machine (we use Ubunut 20.04, but others should be fine)
- Git 2.15 or newer
- CMake 3.21 or newer
- Cuda Toolkit 11.2 or 11.4 (CUDA 11.2 if preferable)
- One NVIDIA A100 GPU (For other types, 3090 and 3080 are evaluated)

### 3.2 Reproducing ```0-main-results```
**First, build GSZ**
```shell
# Step 1: Go to target folder.
cd 0-main-results

# Step 2: Create build folder.
mkdir build && cd build

# Step 3: Use Cmake to setup building environment.
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=../install/ ..

# Step 4: Compile and install.
make -j && make install
```
Then, you can see two executable binary ```gsz_p``` and ```gsz_o``` generated in folder ```0-main-results/install/bin/```. These two executable binary represent GSZ-P and GSZ-O mentioned in paper (especially for Figure 14, Table III, and Figure 21).

**Second, run GSZ**

Still, we use HACC dataset and GSZ-P as an example. GSZ-O will be executed in the exactly same way. Besides, since all fields in one dataset will exhibit similar throughput and consistent compression ratios, so executing one field to showcase the results and compressibility of GSZ compressor.

Given an error bound ```REL 1E-3``` and field ``vx.f32``, GSZ-P can compress it by command:
```shell
cd 0-main-results/install/bin/

./gsz_p vx.f32 1e-3 
# 1e-3 here denotes the relative error bound;
# you can also set it as 0.001.
```
After that, you can see output as below:
```shell
GSZ finished!
GSZ compression   end-to-end speed: 359.554510 GB/s
GSZ decompression end-to-end speed: 437.775719 GB/s
GSZ compression ratio: 5.365436

Pass error check!
```

- The compression end-to-end speed (i.e. throughput) reflects to the HACC bar mentioned in Figure-14-(c).
- The decompression end-to-end speed (i.e. throughput) reflects to the HACC bar mentioned in Figure-14-(d).
- The compression ratio is reported in Table III.
- If you are executing those scripts in other GPUs, such as 3080 and 3080. The throughput that reported denote Figure-21.
- The ```Pass error check!``` is the interal error bound checking script, which can be found in Line86 to Line99 in ```0-main-results/examples/gsz_p.cpp``` and ```0-main-results/examples/gsz_o.cpp```.

Other datasets and GSZ-O will work in the same way.

**Third, one command line execution (highly recommended!)**

In this part, we can reproduce all experiments about Figure 14 and Table III with several wrap-up python (version 3+) command lines, including:
1. Dataset prepartion.
2. GSZ compilation.
3. Execution and results observation. (this step can reproduce the results)
4. Figure drawing. (if needed)

The first three procedures are explained in the code block below.
```shell
# Step 1: Dataset preparation
cd SC24-cuSZp2/
python dataset-preparation.py
# After that, all datasets will be prepared in the folder SC24-cuSZp2/dataset, and we can go to the next step (btw, this step may take some time since the dataset is large).

# Step 2: GSZ compilation
cd SC24-cuSZp2/0-main-results
python 0-compilation.py
# After that, the compilation of GSZ will be finished, and we can go to the next step (execution).

# Step 3: GSZ execution
cd SC24-cuSZp2/0-main-results # The same folder as Step 2.
python 1-execution.py ERROR-BOUND-YOU-WANT-TO-EXECUTE
# There are 3 error-bounds are used in Fig.14), so the demo input includes:
#   python 1-execution.py 1E-2
#   python 1-execution.py 1E-3
#   python 1-execution.py 1E-4
```

After the execution, you can observe an output. We use ```python 1-execution.py 1E-3``` to understand such output. After that, you can see a generated output as shown in the following code block.
```shell
====================================================================
Done with Execution GSZ-P and GSZ-O on cesm_atm under 1e-3
GSZ-P   compression throughput: 267.28176896969694 GB/s
GSZ-P decompression throughput: 395.9575038787878 GB/s
GSZ-P    max compression ratio: 39.039537
GSZ-P    min compression ratio: 2.776141
GSZ-P    avg compression ratio: 14.53542281818182

GSZ-O   compression throughput: 256.82364506060605 GB/s
GSZ-O decompression throughput: 409.47252312121213 GB/s
GSZ-O    max compression ratio: 57.453092
GSZ-O    min compression ratio: 12.995819
GSZ-O    avg compression ratio: 24.53496509090909
====================================================================

====================================================================
Done with Execution GSZ-P and GSZ-O on hacc under 1e-3
GSZ-P   compression throughput: 339.03042400000004 GB/s
GSZ-P decompression throughput: 431.46155999999996 GB/s
GSZ-P    max compression ratio: 5.365436
GSZ-P    min compression ratio: 3.451861
GSZ-P    avg compression ratio: 4.405594000000001

GSZ-O   compression throughput: 344.9251053333334 GB/s
GSZ-O decompression throughput: 459.2428156666667 GB/s
GSZ-O    max compression ratio: 12.470066
GSZ-O    min compression ratio: 5.851711
GSZ-O    avg compression ratio: 8.823446833333334
====================================================================

====================================================================
Done with Execution GSZ-P and GSZ-O on scale under 1e-3
GSZ-P   compression throughput: 240.40884108333333 GB/s
GSZ-P decompression throughput: 335.2613445 GB/s
GSZ-P    max compression ratio: 72.598979
GSZ-P    min compression ratio: 2.750328
GSZ-P    avg compression ratio: 21.11330458333333

GSZ-O   compression throughput: 250.15284741666665 GB/s
GSZ-O decompression throughput: 316.6550965833334 GB/s
GSZ-O    max compression ratio: 79.695224
GSZ-O    min compression ratio: 11.102816
GSZ-O    avg compression ratio: 29.52363491666667
====================================================================

====================================================================
Done with Execution GSZ-P and GSZ-O on qmcpack under 1e-3
GSZ-P   compression throughput: 236.19716549999998 GB/s
GSZ-P decompression throughput: 315.8376475 GB/s
GSZ-P    max compression ratio: 10.075567
GSZ-P    min compression ratio: 6.076028
GSZ-P    avg compression ratio: 8.0757975

GSZ-O   compression throughput: 183.3123765 GB/s
GSZ-O decompression throughput: 319.8198355 GB/s
GSZ-O    max compression ratio: 13.296692
GSZ-O    min compression ratio: 6.077027
GSZ-O    avg compression ratio: 9.6868595
====================================================================

====================================================================
Done with Execution GSZ-P and GSZ-O on nyx under 1e-3
GSZ-P   compression throughput: 244.1977426666667 GB/s
GSZ-P decompression throughput: 305.4707613333333 GB/s
GSZ-P    max compression ratio: 125.551299
GSZ-P    min compression ratio: 5.090097
GSZ-P    avg compression ratio: 38.44212666666666

GSZ-O   compression throughput: 244.53299016666665 GB/s
GSZ-O decompression throughput: 326.64762433333334 GB/s
GSZ-O    max compression ratio: 125.560284
GSZ-O    min compression ratio: 10.501972
GSZ-O    avg compression ratio: 41.756694333333336
====================================================================

====================================================================
Done with Execution GSZ-P and GSZ-O on jetin under 1e-3
GSZ-P   compression throughput: 559.848637 GB/s
GSZ-P decompression throughput: 2626.161979 GB/s
GSZ-P    max compression ratio: 119.858277
GSZ-P    min compression ratio: 119.858277
GSZ-P    avg compression ratio: 119.858277

GSZ-O   compression throughput: 554.342144 GB/s
GSZ-O decompression throughput: 2658.088986 GB/s
GSZ-O    max compression ratio: 120.064674
GSZ-O    min compression ratio: 120.064674
GSZ-O    avg compression ratio: 120.064674
====================================================================

====================================================================
Done with Execution GSZ-P and GSZ-O on miranda under 1e-3
GSZ-P   compression throughput: 297.81917 GB/s
GSZ-P decompression throughput: 420.187394 GB/s
GSZ-P    max compression ratio: 3.038741
GSZ-P    min compression ratio: 3.038741
GSZ-P    avg compression ratio: 3.038741

GSZ-O   compression throughput: 330.657079 GB/s
GSZ-O decompression throughput: 423.426028 GB/s
GSZ-O    max compression ratio: 5.981446
GSZ-O    min compression ratio: 5.981446
GSZ-O    avg compression ratio: 5.981446
====================================================================

====================================================================
Done with Execution GSZ-P and GSZ-O on syntruss under 1e-3
GSZ-P   compression throughput: 319.446766 GB/s
GSZ-P decompression throughput: 317.919891 GB/s
GSZ-P    max compression ratio: 6.371377
GSZ-P    min compression ratio: 6.371377
GSZ-P    avg compression ratio: 6.371377

GSZ-O   compression throughput: 354.674088 GB/s
GSZ-O decompression throughput: 485.769935 GB/s
GSZ-O    max compression ratio: 6.470316
GSZ-O    min compression ratio: 6.470316
GSZ-O    avg compression ratio: 6.470316
====================================================================
```
To understand such results.
- "1E-3" denotes throughput results in Fig.14 (c) and (d)
- 
 
At last, we provide scripts to generate Fig.14. Note that ```gnuplot``` and ```mogrify``` are required.

### 3.3 Reproducing ```1-double-precision```
To be updated later.

### 3.4 Reproducing ```2-random-access```
To be updated later.