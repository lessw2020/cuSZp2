#include "GSZ_entry.h"
#include "GSZ.h"

/** ************************************************************************
 * @brief GSZ end-to-end compression API for host pointers
 *        Compression is executed in GPU.
 *        Original data is stored as host pointers (in CPU).
 *        Compressed data is stored back as host pointers (in CPU).
 * 
 * @param   oriData         original data (host pointer)
 * @param   cmpBytes        compressed data (host pointer)
 * @param   nbEle           original data size (number of floating point)
 * @param   cmpSize         compressed data size (number of unsigned char)
 * @param   errorBound      user-defined error bound
 * *********************************************************************** */
void GSZ_compress_hostptr(float* oriData, unsigned char* cmpBytes, size_t nbEle, size_t* cmpSize, float errorBound)
{
    // Data blocking.
    int bsize = cmp_tblock_size;
    int gsize = (nbEle + bsize * cmp_chunk - 1) / (bsize * cmp_chunk);
    int cmpOffSize = gsize + 1;
    int pad_nbEle = gsize * bsize * cmp_chunk;

    // Initializing global memory for GPU compression.
    float* d_oriData;
    unsigned char* d_cmpData;
    unsigned int* d_cmpOffset;
    unsigned int* d_locOffset;
    int* d_flag;
    unsigned int glob_sync;
    cudaMalloc((void**)&d_oriData, sizeof(float)*pad_nbEle);
    cudaMemcpy(d_oriData, oriData, sizeof(float)*pad_nbEle, cudaMemcpyHostToDevice);
    cudaMalloc((void**)&d_cmpData, sizeof(float)*pad_nbEle);
    cudaMalloc((void**)&d_cmpOffset, sizeof(unsigned int)*cmpOffSize);
    cudaMemset(d_cmpOffset, 0, sizeof(unsigned int)*cmpOffSize);
    cudaMalloc((void**)&d_locOffset, sizeof(unsigned int)*cmpOffSize);
    cudaMemset(d_locOffset, 0, sizeof(unsigned int)*cmpOffSize);
    cudaMalloc((void**)&d_flag, sizeof(int)*cmpOffSize);
    cudaMemset(d_flag, 0, sizeof(int)*cmpOffSize);

    // Initializing CUDA Stream.
    cudaStream_t stream;
    cudaStreamCreate(&stream);

    // GSZ GPU compression.
    dim3 blockSize(bsize);
    dim3 gridSize(gsize);
    GSZ_compress_kernel_plain<<<gridSize, blockSize, sizeof(unsigned int)*2, stream>>>(d_oriData, d_cmpData, d_cmpOffset, d_locOffset, d_flag, errorBound, nbEle);

    // Obtain compression ratio and move data back to CPU.  
    cudaMemcpy(&glob_sync, d_cmpOffset+cmpOffSize-2, sizeof(unsigned int), cudaMemcpyDeviceToHost);
    // Yafan@2023 Sep.20: Didn't add the last block info, so the compression is slightly compromised. 
    //                    Temporarilly adding one gsize to solve this. 
    //                    More solutions will be added in the future.
    // Yafan@2023 Oct.21: New update can be found in cuSZp open-source repo.
    *cmpSize = (size_t)glob_sync + pad_nbEle/32 + 2*gsize;
    cudaMemcpy(cmpBytes, d_cmpData, *cmpSize*sizeof(unsigned char), cudaMemcpyDeviceToHost);

    // Free memory that is used.
    cudaFree(d_oriData);
    cudaFree(d_cmpData);
    cudaFree(d_cmpOffset);
    cudaFree(d_locOffset);
    cudaFree(d_flag);
    cudaStreamDestroy(stream);
}

/** ************************************************************************
 * @brief GSZ end-to-end decompression API for host pointers
 *        Decompression is executed in GPU.
 *        Compressed data is stored as host pointers (in CPU).
 *        Reconstructed data is stored back as host pointers (in CPU).
 *        P.S. Reconstructed data and original data have the same shape.
 * 
 * @param   decData         reconstructed data (host pointer)
 * @param   cmpBytes        compressed data (host pointer)
 * @param   nbEle           reconstructed data size (number of floating point)
 * @param   cmpSize         compressed data size (number of unsigned char)
 * @param   errorBound      user-defined error bound
 * *********************************************************************** */
void GSZ_decompress_hostptr(float* decData, unsigned char* cmpBytes, size_t nbEle, size_t cmpSize, float errorBound)
{
    // Data blocking.
    int bsize = dec_tblock_size;
    int gsize = (nbEle + bsize * dec_chunk - 1) / (bsize * dec_chunk);
    int cmpOffSize = gsize + 1;
    int pad_nbEle = gsize * bsize * dec_chunk;

    // Initializing global memory for GPU compression.
    float* d_decData;
    unsigned char* d_cmpData;
    unsigned int* d_cmpOffset;
    unsigned int* d_locOffset;
    int* d_flag;
    cudaMalloc((void**)&d_decData, sizeof(float)*pad_nbEle);
    cudaMemset(d_decData, 0, sizeof(float)*pad_nbEle);
    cudaMalloc((void**)&d_cmpData, sizeof(float)*pad_nbEle);
    cudaMemcpy(d_cmpData, cmpBytes, sizeof(unsigned char)*cmpSize, cudaMemcpyHostToDevice);
    cudaMalloc((void**)&d_cmpOffset, sizeof(unsigned int)*cmpOffSize);
    cudaMemset(d_cmpOffset, 0, sizeof(unsigned int)*cmpOffSize);
    cudaMalloc((void**)&d_locOffset, sizeof(unsigned int)*cmpOffSize);
    cudaMemset(d_locOffset, 0, sizeof(unsigned int)*cmpOffSize);
    cudaMalloc((void**)&d_flag, sizeof(int)*cmpOffSize);
    cudaMemset(d_flag, 0, sizeof(int)*cmpOffSize);

    // Initializing CUDA Stream.
    cudaStream_t stream;
    cudaStreamCreate(&stream);

    // GSZ GPU decompression.
    dim3 blockSize(bsize);
    dim3 gridSize(gsize);
    GSZ_decompress_kernel_plain<<<gridSize, blockSize, sizeof(unsigned int)*2, stream>>>(d_decData, d_cmpData, d_cmpOffset, d_locOffset, d_flag, errorBound, nbEle);

    // Move data back to CPU.
    cudaMemcpy(decData, d_decData, sizeof(float)*pad_nbEle, cudaMemcpyDeviceToHost);

    // Free memoy that is used.
    cudaFree(d_decData);
    cudaFree(d_cmpData);
    cudaFree(d_cmpOffset);
    cudaFree(d_locOffset);
    cudaFree(d_flag);
    cudaStreamDestroy(stream);
}

/** ************************************************************************
 * @brief GSZ end-to-end compression API for device pointers
 *        Compression is executed in GPU.
 *        Original data is stored as device pointers (in GPU).
 *        Compressed data is stored back as device pointers (in GPU).
 * 
 * @param   d_oriData       original data (device pointer)
 * @param   d_cmpBytes      compressed data (device pointer)
 * @param   nbEle           original data size (number of floating point)
 * @param   cmpSize         compressed data size (number of unsigned char)
 * @param   errorBound      user-defined error bound
 * @param   stream          CUDA stream for executing compression kernel
 * *********************************************************************** */
void GSZ_compress_deviceptr_plain(float* d_oriData, unsigned char* d_cmpBytes, size_t nbEle, size_t* cmpSize, float errorBound, cudaStream_t stream)
{
    // Data blocking.
    int bsize = cmp_tblock_size;
    int gsize = (nbEle + bsize * cmp_chunk - 1) / (bsize * cmp_chunk);
    int cmpOffSize = gsize + 1;

    // Initializing global memory for GPU compression.
    unsigned int* d_cmpOffset;
    unsigned int* d_locOffset;
    int* d_flag;
    unsigned int glob_sync;
    cudaMalloc((void**)&d_cmpOffset, sizeof(unsigned int)*cmpOffSize);
    cudaMemset(d_cmpOffset, 0, sizeof(unsigned int)*cmpOffSize);
    cudaMalloc((void**)&d_locOffset, sizeof(unsigned int)*cmpOffSize);
    cudaMemset(d_locOffset, 0, sizeof(unsigned int)*cmpOffSize);
    cudaMalloc((void**)&d_flag, sizeof(int)*cmpOffSize);
    cudaMemset(d_flag, 0, sizeof(int)*cmpOffSize);

    // GSZ GPU compression.
    dim3 blockSize(bsize);
    dim3 gridSize(gsize);
    GSZ_compress_kernel_plain<<<gridSize, blockSize, sizeof(unsigned int)*2, stream>>>(d_oriData, d_cmpBytes, d_cmpOffset, d_locOffset, d_flag, errorBound, nbEle);

    // Obtain compression ratio and move data back to CPU.  
    cudaMemcpy(&glob_sync, d_cmpOffset+cmpOffSize-2, sizeof(unsigned int), cudaMemcpyDeviceToHost);
    *cmpSize = (size_t)glob_sync + (nbEle+cmp_tblock_size*cmp_chunk-1)/(cmp_tblock_size*cmp_chunk)*(cmp_tblock_size*cmp_chunk)/32;

    // Free memory that is used.
    cudaFree(d_cmpOffset);
    cudaFree(d_locOffset);
    cudaFree(d_flag);
}

 /** ************************************************************************
 * @brief GSZ end-to-end decompression API for device pointers
 *        Decompression is executed in GPU.
 *        Compressed data is stored as device pointers (in GPU).
 *        Reconstructed data is stored as device pointers (in GPU).
 *        P.S. Reconstructed data and original data have the same shape.
 * 
 * @param   d_decData       reconstructed data (device pointer)
 * @param   d_cmpBytes      compressed data (device pointer)
 * @param   nbEle           reconstructed data size (number of floating point)
 * @param   cmpSize         compressed data size (number of unsigned char)
 * @param   errorBound      user-defined error bound
 * @param   stream          CUDA stream for executing compression kernel
 * *********************************************************************** */
void GSZ_decompress_deviceptr_plain(float* d_decData, unsigned char* d_cmpBytes, size_t nbEle, size_t cmpSize, float errorBound, cudaStream_t stream)
{
    // Data blocking.
    int bsize = dec_tblock_size;
    int gsize = (nbEle + bsize * dec_chunk - 1) / (bsize * dec_chunk);
    int cmpOffSize = gsize + 1;

    // Initializing global memory for GPU decompression.
    unsigned int* d_cmpOffset;
    unsigned int* d_locOffset;
    int* d_flag;
    cudaMalloc((void**)&d_cmpOffset, sizeof(unsigned int)*cmpOffSize);
    cudaMemset(d_cmpOffset, 0, sizeof(unsigned int)*cmpOffSize);
    cudaMalloc((void**)&d_locOffset, sizeof(unsigned int)*cmpOffSize);
    cudaMemset(d_locOffset, 0, sizeof(unsigned int)*cmpOffSize);
    cudaMalloc((void**)&d_flag, sizeof(int)*cmpOffSize);
    cudaMemset(d_flag, 0, sizeof(int)*cmpOffSize);

    // GSZ GPU decompression.
    dim3 blockSize(bsize);
    dim3 gridSize(gsize);
    GSZ_decompress_kernel_plain<<<gridSize, blockSize, sizeof(unsigned int)*2, stream>>>(d_decData, d_cmpBytes, d_cmpOffset, d_locOffset, d_flag, errorBound, nbEle);
    
    // Free memory that is used.
    cudaFree(d_cmpOffset);
    cudaFree(d_locOffset);
    cudaFree(d_flag);
}

/** ************************************************************************
 * @brief GSZ end-to-end compression API for device pointers
 *        Compression is executed in GPU.
 *        Original data is stored as device pointers (in GPU).
 *        Compressed data is stored back as device pointers (in GPU).
 * 
 * @param   d_oriData       original data (device pointer)
 * @param   d_cmpBytes      compressed data (device pointer)
 * @param   nbEle           original data size (number of floating point)
 * @param   cmpSize         compressed data size (number of unsigned char)
 * @param   errorBound      user-defined error bound
 * @param   stream          CUDA stream for executing compression kernel
 * *********************************************************************** */
void GSZ_compress_deviceptr_outlier(float* d_oriData, unsigned char* d_cmpBytes, size_t nbEle, size_t* cmpSize, float errorBound, cudaStream_t stream)
{
    // Data blocking.
    int bsize = cmp_tblock_size;
    int gsize = (nbEle + bsize * cmp_chunk - 1) / (bsize * cmp_chunk);
    int cmpOffSize = gsize + 1;

    // Initializing global memory for GPU compression.
    unsigned int* d_cmpOffset;
    unsigned int* d_locOffset;
    int* d_flag;
    unsigned int glob_sync;
    cudaMalloc((void**)&d_cmpOffset, sizeof(unsigned int)*cmpOffSize);
    cudaMemset(d_cmpOffset, 0, sizeof(unsigned int)*cmpOffSize);
    cudaMalloc((void**)&d_locOffset, sizeof(unsigned int)*cmpOffSize);
    cudaMemset(d_locOffset, 0, sizeof(unsigned int)*cmpOffSize);
    cudaMalloc((void**)&d_flag, sizeof(int)*cmpOffSize);
    cudaMemset(d_flag, 0, sizeof(int)*cmpOffSize);

    // GSZ GPU compression.
    dim3 blockSize(bsize);
    dim3 gridSize(gsize);
    GSZ_compress_kernel_outlier<<<gridSize, blockSize, sizeof(unsigned int)*2, stream>>>(d_oriData, d_cmpBytes, d_cmpOffset, d_locOffset, d_flag, errorBound, nbEle);

    // Obtain compression ratio and move data back to CPU.  
    cudaMemcpy(&glob_sync, d_cmpOffset+cmpOffSize-2, sizeof(unsigned int), cudaMemcpyDeviceToHost);
    *cmpSize = (size_t)glob_sync + (nbEle+cmp_tblock_size*cmp_chunk-1)/(cmp_tblock_size*cmp_chunk)*(cmp_tblock_size*cmp_chunk)/32;

    // Free memory that is used.
    cudaFree(d_cmpOffset);
    cudaFree(d_locOffset);
    cudaFree(d_flag);
}

 /** ************************************************************************
 * @brief GSZ end-to-end decompression API for device pointers
 *        Decompression is executed in GPU.
 *        Compressed data is stored as device pointers (in GPU).
 *        Reconstructed data is stored as device pointers (in GPU).
 *        P.S. Reconstructed data and original data have the same shape.
 * 
 * @param   d_decData       reconstructed data (device pointer)
 * @param   d_cmpBytes      compressed data (device pointer)
 * @param   nbEle           reconstructed data size (number of floating point)
 * @param   cmpSize         compressed data size (number of unsigned char)
 * @param   errorBound      user-defined error bound
 * @param   stream          CUDA stream for executing compression kernel
 * *********************************************************************** */
void GSZ_decompress_deviceptr_outlier(float* d_decData, unsigned char* d_cmpBytes, size_t nbEle, size_t cmpSize, float errorBound, cudaStream_t stream)
{
    // Data blocking.
    int bsize = dec_tblock_size;
    int gsize = (nbEle + bsize * dec_chunk - 1) / (bsize * dec_chunk);
    int cmpOffSize = gsize + 1;

    // Initializing global memory for GPU decompression.
    unsigned int* d_cmpOffset;
    unsigned int* d_locOffset;
    int* d_flag;
    cudaMalloc((void**)&d_cmpOffset, sizeof(unsigned int)*cmpOffSize);
    cudaMemset(d_cmpOffset, 0, sizeof(unsigned int)*cmpOffSize);
    cudaMalloc((void**)&d_locOffset, sizeof(unsigned int)*cmpOffSize);
    cudaMemset(d_locOffset, 0, sizeof(unsigned int)*cmpOffSize);
    cudaMalloc((void**)&d_flag, sizeof(int)*cmpOffSize);
    cudaMemset(d_flag, 0, sizeof(int)*cmpOffSize);

    // GSZ GPU decompression.
    dim3 blockSize(bsize);
    dim3 gridSize(gsize);
    GSZ_decompress_kernel_outlier<<<gridSize, blockSize, sizeof(unsigned int)*2, stream>>>(d_decData, d_cmpBytes, d_cmpOffset, d_locOffset, d_flag, errorBound, nbEle);
    
    // Free memory that is used.
    cudaFree(d_cmpOffset);
    cudaFree(d_locOffset);
    cudaFree(d_flag);
}