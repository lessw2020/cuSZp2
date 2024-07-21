# SC24-cuSZp2
cuSZp2 (a.k.a. name as GSZ in Paper) is a lossy error-bounded compression library specifically for NVIDIA GPUs for compression of floating-point data. This repository is used for AD-AE process for SC'24 conference. More details and arranged code will be updated later in cuSZp repository [\[LINK\]](https://github.com/szcompressor/cuSZp). Note that in this repo we temporarily use the name "GSZ", which will be updated very soon.

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