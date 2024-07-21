#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <math.h>
#include <GSZ_utility.h>
#include <GSZ_entry.h>

int main(int argc, char* argv[])
{
    // Read input information.
    char oriFilePath[640];
    int status=0;
    if(argc != 3)
    {
        printf("Usage: cpu_api_GSZ [srcFilePath] [relErrBound]\n");
        printf("Example: cpu_api_GSZ testfloat_8_8_128.dat 1e-3\n");
        exit(0);
    }
    sprintf(oriFilePath, "%s", argv[1]);
    float errorBound = atof(argv[2]);

    // Input data preparation.
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

    // GSZ compression.
    GSZ_compress_hostptr(oriData, cmpBytes, nbEle, &cmpSize, errorBound);
    
    // GSZ decompression.
    GSZ_decompress_hostptr(decData, cmpBytes, nbEle, cmpSize, errorBound);

    // Print result.
    printf("GSZ finished!\n");
    printf("compression ratios: %f\n\n", (nbEle*sizeof(float)/1024.0/1024.0)/(cmpSize*sizeof(unsigned char)/1024.0/1024.0));

    // Error check
    int not_bound = 0;
    for(size_t i=0; i<nbEle; i+=1)
    {
        if(fabs(oriData[i]-decData[i]) > errorBound*3)
        {
            not_bound++;
            printf("not bound: %zu oriData: %f, decData: %f, errors: %f, bound: %f\n", i, oriData[i], decData[i], fabs(oriData[i]-decData[i]), errorBound);
        }
    }
    if(!not_bound) printf("\033[0;32mPass error check!\033[0m\n");
    else printf("\033[0;31mFail error check! Exceeding data count: %d\033[0m\n", not_bound);
    
    free(oriData);
    free(decData);
    free(cmpBytes);
    return 0;
}