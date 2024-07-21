#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <math.h>
#include <cuda_runtime.h>
#include <GSZ_utility.h>
#include <GSZ_entry.h>
#include <GSZ_timer.h>

int main(int argc, char* argv[])
{
    // Read input information.
    char oriFilePath[640];
    int status=0;
    if(argc != 3)
    {
        printf("Usage: gpu_api_GSZ [srcFilePath] [relErrBound]\n");
        printf("Example: gpu_api_GSZ testfloat_8_8_128.dat 1e-3\n");
        exit(0);
    }
    sprintf(oriFilePath, "%s", argv[1]);
    float errorBound = atof(argv[2]);

    // For measuring the end-to-end throughput.
    TimingGPU timer_GPU;

    // Input data preparation on CPU.
    float* oriData = NULL;
    float* decData = NULL;
    unsigned char* cmpBytes = NULL;
    size_t nbEle = 0;
    size_t cmpSize = 0;
    oriData = readFloatData_Yafan(oriFilePath, &nbEle, &status);
    decData = (float*)malloc(nbEle*sizeof(float));
    cmpBytes = (unsigned char*)malloc(nbEle*sizeof(float));

    /* Yafan added for RTM Project. CAN BE REMOVED*/
    // Get value range, making it a REL errMode test.
    float max_val = oriData[0];
    float min_val = oriData[0];
    for(size_t i=0; i<nbEle; i++)
    {
        if(oriData[i]>max_val)
            max_val = oriData[i];
        else if(oriData[i]<min_val)
            min_val = oriData[i];
    }
    errorBound = errorBound * (max_val - min_val);

    // Input data preparation on GPU.
    float* d_oriData;
    float* d_decData;
    unsigned char* d_cmpBytes;
    size_t pad_nbEle = (nbEle + 32768 - 1) / 32768 * 32768; // A temp demo, will add more block sizes in future implementation.
    cudaMalloc((void**)&d_oriData, sizeof(float)*pad_nbEle);
    cudaMemcpy(d_oriData, oriData, sizeof(float)*pad_nbEle, cudaMemcpyHostToDevice);
    cudaMalloc((void**)&d_decData, sizeof(float)*pad_nbEle);
    cudaMalloc((void**)&d_cmpBytes, sizeof(float)*pad_nbEle);

    // Initializing CUDA Stream.
    cudaStream_t stream;
    cudaStreamCreate(&stream);
    
    // Warmup for NVIDIA GPU.
    for(int i=0; i<3; i++)
    {
        GSZ_compress_deviceptr(d_oriData, d_cmpBytes, nbEle, &cmpSize, errorBound, stream);
    }

    // GSZ compression.
    timer_GPU.StartCounter(); // set timer
    GSZ_compress_deviceptr(d_oriData, d_cmpBytes, nbEle, &cmpSize, errorBound, stream);
    float cmpTime = timer_GPU.GetCounter();
        
    // GSZ decompression.
    timer_GPU.StartCounter(); // set timer
    GSZ_decompress_deviceptr(d_decData, d_cmpBytes, nbEle, cmpSize, errorBound, stream);
    float decTime = timer_GPU.GetCounter();

    // Print result.
    printf("GSZ finished!\n");
    printf("GSZ compression   end-to-end speed: %f GB/s\n", (nbEle*sizeof(float)/1024.0/1024.0)/cmpTime);
    printf("GSZ decompression end-to-end speed: %f GB/s\n", (nbEle*sizeof(float)/1024.0/1024.0)/decTime);
    printf("GSZ compression ratio: %f\n\n", (nbEle*sizeof(float)/1024.0/1024.0)/(cmpSize*sizeof(unsigned char)/1024.0/1024.0));
    
    // Error check
    cudaMemcpy(cmpBytes, d_cmpBytes, cmpSize*sizeof(unsigned char), cudaMemcpyDeviceToHost);
    cudaMemcpy(decData, d_decData, sizeof(float)*nbEle, cudaMemcpyDeviceToHost);
    int not_bound = 0;
    for(size_t i=0; i<nbEle; i+=1)
    {
        if(fabs(oriData[i]-decData[i]) > errorBound*1.1)
        {
            not_bound++;
            // printf("not bound: %zu oriData: %f, decData: %f, errors: %f, bound: %f\n", i, oriData[i], decData[i], fabs(oriData[i]-decData[i]), errorBound);
        }
    }
    if(!not_bound) printf("\033[0;32mPass error check!\033[0m\n");
    else printf("\033[0;31mFail error check! Exceeding data count: %d\033[0m\n", not_bound);
   
    free(oriData);
    free(decData);
    free(cmpBytes);
    cudaFree(d_oriData);
    cudaFree(d_decData);
    cudaFree(d_cmpBytes);
    cudaStreamDestroy(stream);
    return 0;
}