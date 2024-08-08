#ifndef GSZ_INCLUDE_GSZ_ENTRY_H
#define GSZ_INCLUDE_GSZ_ENTRY_H

#include <cuda_runtime.h>

void GSZ_compress_hostptr(double* oriData, unsigned char* cmpBytes, size_t nbEle, size_t* cmpSize, double errorBound);
void GSZ_decompress_hostptr(double* decData, unsigned char* cmpBytes, size_t nbEle, size_t cmpSize, double errorBound);
void GSZ_compress_deviceptr_plain(double* d_oriData, unsigned char* d_cmpBytes, size_t nbEle, size_t* cmpSize, double errorBound, cudaStream_t stream = 0);
void GSZ_decompress_deviceptr_plain(double* d_decData, unsigned char* d_cmpBytes, size_t nbEle, size_t cmpSize, double errorBound, cudaStream_t stream = 0);
void GSZ_compress_deviceptr_outlier(double* d_oriData, unsigned char* d_cmpBytes, size_t nbEle, size_t* cmpSize, double errorBound, cudaStream_t stream = 0);
void GSZ_decompress_deviceptr_outlier(double* d_decData, unsigned char* d_cmpBytes, size_t nbEle, size_t cmpSize, double errorBound, cudaStream_t stream = 0);

#endif // GSZ_INCLUDE_GSZ_ENTRY_H