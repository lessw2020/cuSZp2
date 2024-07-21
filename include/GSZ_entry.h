#ifndef GSZ_INCLUDE_GSZ_ENTRY_H
#define GSZ_INCLUDE_GSZ_ENTRY_H

#include <cuda_runtime.h>

void GSZ_compress_hostptr(float* oriData, unsigned char* cmpBytes, size_t nbEle, size_t* cmpSize, float errorBound);
void GSZ_decompress_hostptr(float* decData, unsigned char* cmpBytes, size_t nbEle, size_t cmpSize, float errorBound);
void GSZ_compress_deviceptr(float* d_oriData, unsigned char* d_cmpBytes, size_t nbEle, size_t* cmpSize, float errorBound, cudaStream_t stream = 0);
void GSZ_decompress_deviceptr(float* d_decData, unsigned char* d_cmpBytes, size_t nbEle, size_t cmpSize, float errorBound, cudaStream_t stream = 0);

#endif // GSZ_INCLUDE_GSZ_ENTRY_H