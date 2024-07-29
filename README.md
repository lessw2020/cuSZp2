# SC24-cuSZp2

## Introduction
cuSZp2 (a.k.a. name as GSZ in paper submission) is a lossy error-bounded compression library specifically for NVIDIA GPUs for compression of floating-point data. This repository is used for AD-AE process for SC'24 conference. The official and final version of cuSZp2 will be updated into cuSZp repository [\[LINK\]](https://github.com/szcompressor/cuSZp) in the future. <u>For simplicity, we will still use the name **GSZ** in this repository, to align what is reported in the submission version.</u>

Before we start the AD/AE process, here are some regular QAs:
- **Information about lossy compressor and HPC?**
  - HPC simulation, such as quantum simulation or climate simulation, turns to produce very large dataset. While lossless compression has limited compression ratio, lossy compression can achieve very high compression ratio with user tolerable errors.
- **How does lossy compressor work?**
  - There are two phases of a lossy compressor: **Compression** and **Decompression**. Compression takes an HPC dataset (e.g. vx.f32 from HACC dataset) as input to compress and generates the compressed HPC dataset as output. Meanwhile, decompression takes an compressed dataset as input and decomressed it to reconstructed (we can also call it decompressed) dataset as output.
- **What is GPU lossy compressor?**
  - GPU lossy compressor indicates the compression and decompression computations are executed in GPU. Why? Because GPU can do this much faster.
- **Why we propose GSZ and how to evaluate it?**
  - Existing GPU compressor is slow, so we propose an extremely fast GPU compressor -- GSZ. _As a result, the main contribution of GSZ is its throughput (GB/s)_, which can be understood as data processing speed. But the improved speed cannot be sacrifised from other metrics like compression ratio, _so another important metric is compression ratio, computed by_ $OriDataSize/CmpDataSize$.

## Dataset Download and Information
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
```

```
Usually But some dataset only has one field, then

## 
explanation, which part denotes where
Explanation about the relationship between each dataset and each figure.

## 
compilation and experiments conducts for each step

## Environment Requirements
### Common
- Git 2.15 or newer
- CMake 3.21 or newer
- Cuda Toolkit 11.2 or 11.4 (these two versions pass testing)

## Installation
To build GSZ:
```
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=../install/ ..
make -j
make install
```


## To use GSZ
You can find executable binary in ```./install/bin/```.
```
# Format: ./gpu_api_GSZ data-you-want-to-compress relative-error-bound
# And an example can be shown as below:
./gpu_api_GSZ ./hacc/vx.f32 1e-4
```