#include "GSZ.h"

 /** ************************************************************************
 * @brief Pre-quantization for one float point data.
 *        Device function, inline PTX assembly version.
 * 
 * @param   data            input float point data
 * @param   recipPrecision  reciprocal of 2 x user-defined error bound
 *
 * @return  result          quantization integer for the input fp
 * *********************************************************************** */
__device__ inline int quantization(float data, float recipPrecision)
{
    int result;
    asm("{\n\t"
        ".reg .f32 dataRecip;\n\t"
        ".reg .f32 temp1;\n\t"
        ".reg .s32 s;\n\t"
        ".reg .pred p;\n\t"
        "mul.f32 dataRecip, %1, %2;\n\t"        // dataRecip = data * recipPrecision
        "setp.ge.f32 p, dataRecip, -0.5;\n\t"   // Set predicate if dataRecip >= -0.5
        "selp.s32 s, 0, 1, p;\n\t"              // s = 0 if p is true, else s = 1
        "add.f32 temp1, dataRecip, 0.5;\n\t"    // temp1 = dataRecip + 0.5
        "cvt.rzi.s32.f32 %0, temp1;\n\t"        // Convert to int with round towards zero and store to result
        "sub.s32 %0, %0, s;\n\t"                // result = result - s
        "}": "=r"(result) : "f"(data), "f"(recipPrecision)
    );
    return result;
}

 /** ************************************************************************
 * @brief Get number of effective bits for a integer.
 *        Device function, inline PTX assembly version.
 * 
 * @param   x                   input integer
 *
 * @return  (32-leading_zeros)  number of effective bits for x
 * *********************************************************************** */
__device__ inline int get_bit_num(unsigned int x)
{
    int leading_zeros;
    asm("clz.b32 %0, %1;" : "=r"(leading_zeros) : "r"(x));
    return 32 - leading_zeros;
}

 /** ************************************************************************
 * @brief GSZ compression kernel
 *
 * @param   oriData         input original data array
 * @param   cmpData         compressed data array
 * @param   cmpOffset       output global device-scan
 * @param   locOffset       input local device-scan
 * @param   flag            flags for device-scan
 * @param   eb              user-defined error bound
 * @param   nbEle           original data size (number of floating point)
 * *********************************************************************** */
__global__ void GSZ_compress_kernel(const float* const __restrict__ oriData, 
                                    unsigned char* const __restrict__ cmpData, 
                                    volatile unsigned int* const __restrict__ cmpOffset, 
                                    volatile unsigned int* const __restrict__ locOffset, 
                                    volatile int* const __restrict__ flag, 
                                    const float eb, const size_t nbEle)
{
    __shared__ unsigned int excl_sum;
    __shared__ unsigned int base_idx;

    const int tid = threadIdx.x;
    const int bid = blockIdx.x;
    const int idx = bid * blockDim.x + tid;
    const int lane = idx & 0x1f;
    const int warp = idx >> 5;
    const int block_num = cmp_chunk >> 5;
    const int rate_ofs = (nbEle+cmp_tblock_size*cmp_chunk-1)/(cmp_tblock_size*cmp_chunk)*(cmp_tblock_size*cmp_chunk)/32;
    const float recipPrecision = 0.5f/eb;

    int base_start_idx;
    int base_block_start_idx, base_block_end_idx;
    int quant_chunk_idx;
    int block_idx;
    int currQuant, lorenQuant, prevQuant, maxQuant;
    int absQuant[cmp_chunk];
    unsigned int sign_flag[block_num];
    int sign_ofs;
    int fixed_rate[block_num];
    unsigned int thread_ofs = 0;
    float4 tmp_buffer;
    uchar4 tmp_char;

    // Prequantization + Lorenzo Prediction + Fixed-length encoding + store fixed-length to global memory.
    // Accessing data via a vectorized manner.
    base_start_idx = warp * cmp_chunk * 32;
    for(int j=0; j<block_num; j+=4)
    {
        // Vector Initialization.
        block_idx = base_start_idx / 32 + j * 32 + lane * 4;

        // First block: initilization.
        base_block_start_idx = base_start_idx + j * 1024 + lane * 32;
        base_block_end_idx = base_block_start_idx + 32;
        sign_flag[j] = 0;
        prevQuant = 0;
        maxQuant = 0;

        // First block: operation
        #pragma unroll 8
        for(int i=base_block_start_idx; i<base_block_end_idx; i+=4)
        {
            // Read data from global memory.
            tmp_buffer = reinterpret_cast<const float4*>(oriData)[i/4];
            quant_chunk_idx = j * 32 + i % 32;

            // For the .x element, get quantization, lorenzo prediction, get and combine sign info, get absolute value, and update max quant.
            currQuant = quantization(tmp_buffer.x, recipPrecision);
            lorenQuant = currQuant - prevQuant;
            prevQuant = currQuant;
            sign_ofs = i % 32;
            sign_flag[j] |= (lorenQuant < 0) << (31 - sign_ofs);
            absQuant[quant_chunk_idx] = abs(lorenQuant);
            maxQuant = maxQuant > absQuant[quant_chunk_idx] ? maxQuant : absQuant[quant_chunk_idx];

            // For the .y element, get quantization, lorenzo prediction, get and combine sign info, get absolute value, and update max quant.
            currQuant = quantization(tmp_buffer.y, recipPrecision);
            lorenQuant = currQuant - prevQuant;
            prevQuant = currQuant;
            sign_ofs = (i+1) % 32;
            sign_flag[j] |= (lorenQuant < 0) << (31 - sign_ofs);
            absQuant[quant_chunk_idx+1] = abs(lorenQuant);
            maxQuant = maxQuant > absQuant[quant_chunk_idx+1] ? maxQuant : absQuant[quant_chunk_idx+1];

            // For the .z element, get quantization, lorenzo prediction, get and combine sign info, get absolute value, and update max quant.
            currQuant = quantization(tmp_buffer.z, recipPrecision);
            lorenQuant = currQuant - prevQuant;
            prevQuant = currQuant;
            sign_ofs = (i+2) % 32;
            sign_flag[j] |= (lorenQuant < 0) << (31 - sign_ofs);
            absQuant[quant_chunk_idx+2] = abs(lorenQuant);
            maxQuant = maxQuant > absQuant[quant_chunk_idx+2] ? maxQuant : absQuant[quant_chunk_idx+2];

            // For the .w element, get quantization, lorenzo prediction, get and combine sign info, get absolute value, and update max quant.
            currQuant = quantization(tmp_buffer.w, recipPrecision);
            lorenQuant = currQuant - prevQuant;
            prevQuant = currQuant;
            sign_ofs = (i+3) % 32;
            sign_flag[j] |= (lorenQuant < 0) << (31 - sign_ofs);
            absQuant[quant_chunk_idx+3] = abs(lorenQuant);
            maxQuant = maxQuant > absQuant[quant_chunk_idx+3] ? maxQuant : absQuant[quant_chunk_idx+3];
        }

        // First block: record info
        fixed_rate[j] = get_bit_num(maxQuant);
        thread_ofs += (fixed_rate[j]) ? (4+fixed_rate[j]*4) : 0;
        tmp_char.x = (unsigned char)fixed_rate[j];
        __syncthreads();

        // Second block: initilization.
        base_block_start_idx += 1024;
        base_block_end_idx = base_block_start_idx + 32;
        sign_flag[j+1] = 0;
        prevQuant = 0;
        maxQuant = 0;

        // Second block: operation.
        #pragma unroll 8
        for(int i=base_block_start_idx; i<base_block_end_idx; i+=4)
        {
            // Read data from global memory.
            tmp_buffer = reinterpret_cast<const float4*>(oriData)[i/4];
            quant_chunk_idx = (j+1) * 32 + i % 32;

            // For the .x element, get quantization, lorenzo prediction, get and combine sign info, get absolute value, and update max quant.
            currQuant = quantization(tmp_buffer.x, recipPrecision);
            lorenQuant = currQuant - prevQuant;
            prevQuant = currQuant;
            sign_ofs = i % 32;
            sign_flag[j+1] |= (lorenQuant < 0) << (31 - sign_ofs);
            absQuant[quant_chunk_idx] = abs(lorenQuant);
            maxQuant = maxQuant > absQuant[quant_chunk_idx] ? maxQuant : absQuant[quant_chunk_idx];

            // For the .y element, get quantization, lorenzo prediction, get and combine sign info, get absolute value, and update max quant.
            currQuant = quantization(tmp_buffer.y, recipPrecision);
            lorenQuant = currQuant - prevQuant;
            prevQuant = currQuant;
            sign_ofs = (i+1) % 32;
            sign_flag[j+1] |= (lorenQuant < 0) << (31 - sign_ofs);
            absQuant[quant_chunk_idx+1] = abs(lorenQuant);
            maxQuant = maxQuant > absQuant[quant_chunk_idx+1] ? maxQuant : absQuant[quant_chunk_idx+1];

            // For the .z element, get quantization, lorenzo prediction, get and combine sign info, get absolute value, and update max quant.
            currQuant = quantization(tmp_buffer.z, recipPrecision);
            lorenQuant = currQuant - prevQuant;
            prevQuant = currQuant;
            sign_ofs = (i+2) % 32;
            sign_flag[j+1] |= (lorenQuant < 0) << (31 - sign_ofs);
            absQuant[quant_chunk_idx+2] = abs(lorenQuant);
            maxQuant = maxQuant > absQuant[quant_chunk_idx+2] ? maxQuant : absQuant[quant_chunk_idx+2];

            // For the .w element, get quantization, lorenzo prediction, get and combine sign info, get absolute value, and update max quant.
            currQuant = quantization(tmp_buffer.w, recipPrecision);
            lorenQuant = currQuant - prevQuant;
            prevQuant = currQuant;
            sign_ofs = (i+3) % 32;
            sign_flag[j+1] |= (lorenQuant < 0) << (31 - sign_ofs);
            absQuant[quant_chunk_idx+3] = abs(lorenQuant);
            maxQuant = maxQuant > absQuant[quant_chunk_idx+3] ? maxQuant : absQuant[quant_chunk_idx+3];
        }

        // Second block: record info.
        fixed_rate[j+1] = get_bit_num(maxQuant);
        thread_ofs += (fixed_rate[j+1]) ? (4+fixed_rate[j+1]*4) : 0;
        tmp_char.y = (unsigned char)fixed_rate[j+1];
        __syncthreads();

        // Third block: initilization.
        base_block_start_idx += 1024;
        base_block_end_idx = base_block_start_idx + 32;
        sign_flag[j+2] = 0;
        prevQuant = 0;
        maxQuant = 0;

        // Third block: operation.
        #pragma unroll 8
        for(int i=base_block_start_idx; i<base_block_end_idx; i+=4)
        {
            // Read data from global memory.
            tmp_buffer = reinterpret_cast<const float4*>(oriData)[i/4];
            quant_chunk_idx = (j+2) * 32 + i % 32;

            // For the .x element, get quantization, lorenzo prediction, get and combine sign info, get absolute value, and update max quant.
            currQuant = quantization(tmp_buffer.x, recipPrecision);
            lorenQuant = currQuant - prevQuant;
            prevQuant = currQuant;
            sign_ofs = i % 32;
            sign_flag[j+2] |= (lorenQuant < 0) << (31 - sign_ofs);
            absQuant[quant_chunk_idx] = abs(lorenQuant);
            maxQuant = maxQuant > absQuant[quant_chunk_idx] ? maxQuant : absQuant[quant_chunk_idx];

            // For the .y element, get quantization, lorenzo prediction, get and combine sign info, get absolute value, and update max quant.
            currQuant = quantization(tmp_buffer.y, recipPrecision);
            lorenQuant = currQuant - prevQuant;
            prevQuant = currQuant;
            sign_ofs = (i+1) % 32;
            sign_flag[j+2] |= (lorenQuant < 0) << (31 - sign_ofs);
            absQuant[quant_chunk_idx+1] = abs(lorenQuant);
            maxQuant = maxQuant > absQuant[quant_chunk_idx+1] ? maxQuant : absQuant[quant_chunk_idx+1];

            // For the .z element, get quantization, lorenzo prediction, get and combine sign info, get absolute value, and update max quant.
            currQuant = quantization(tmp_buffer.z, recipPrecision);
            lorenQuant = currQuant - prevQuant;
            prevQuant = currQuant;
            sign_ofs = (i+2) % 32;
            sign_flag[j+2] |= (lorenQuant < 0) << (31 - sign_ofs);
            absQuant[quant_chunk_idx+2] = abs(lorenQuant);
            maxQuant = maxQuant > absQuant[quant_chunk_idx+2] ? maxQuant : absQuant[quant_chunk_idx+2];

            // For the .w element, get quantization, lorenzo prediction, get and combine sign info, get absolute value, and update max quant.
            currQuant = quantization(tmp_buffer.w, recipPrecision);
            lorenQuant = currQuant - prevQuant;
            prevQuant = currQuant;
            sign_ofs = (i+3) % 32;
            sign_flag[j+2] |= (lorenQuant < 0) << (31 - sign_ofs);
            absQuant[quant_chunk_idx+3] = abs(lorenQuant);
            maxQuant = maxQuant > absQuant[quant_chunk_idx+3] ? maxQuant : absQuant[quant_chunk_idx+3];
        }

        // Third block: record info.
        fixed_rate[j+2] = get_bit_num(maxQuant);
        thread_ofs += (fixed_rate[j+2]) ? (4+fixed_rate[j+2]*4) : 0;
        tmp_char.z = (unsigned char)fixed_rate[j+2];
        __syncthreads();

        // Fourth block: initilization.
        base_block_start_idx += 1024;
        base_block_end_idx = base_block_start_idx + 32;
        sign_flag[j+3] = 0;
        prevQuant = 0;
        maxQuant = 0;

        // Fourth block: operation.
        #pragma unroll 8
        for(int i=base_block_start_idx; i<base_block_end_idx; i+=4)
        {
            // Read data from global memory.
            tmp_buffer = reinterpret_cast<const float4*>(oriData)[i/4];
            quant_chunk_idx = (j+3) * 32 + i % 32;

            // For the .x element, get quantization, lorenzo prediction, get and combine sign info, get absolute value, and update max quant.
            currQuant = quantization(tmp_buffer.x, recipPrecision);
            lorenQuant = currQuant - prevQuant;
            prevQuant = currQuant;
            sign_ofs = i % 32;
            sign_flag[j+3] |= (lorenQuant < 0) << (31 - sign_ofs);
            absQuant[quant_chunk_idx] = abs(lorenQuant);
            maxQuant = maxQuant > absQuant[quant_chunk_idx] ? maxQuant : absQuant[quant_chunk_idx];

            // For the .y element, get quantization, lorenzo prediction, get and combine sign info, get absolute value, and update max quant.
            currQuant = quantization(tmp_buffer.y, recipPrecision);
            lorenQuant = currQuant - prevQuant;
            prevQuant = currQuant;
            sign_ofs = (i+1) % 32;
            sign_flag[j+3] |= (lorenQuant < 0) << (31 - sign_ofs);
            absQuant[quant_chunk_idx+1] = abs(lorenQuant);
            maxQuant = maxQuant > absQuant[quant_chunk_idx+1] ? maxQuant : absQuant[quant_chunk_idx+1];

            // For the .z element, get quantization, lorenzo prediction, get and combine sign info, get absolute value, and update max quant.
            currQuant = quantization(tmp_buffer.z, recipPrecision);
            lorenQuant = currQuant - prevQuant;
            prevQuant = currQuant;
            sign_ofs = (i+2) % 32;
            sign_flag[j+3] |= (lorenQuant < 0) << (31 - sign_ofs);
            absQuant[quant_chunk_idx+2] = abs(lorenQuant);
            maxQuant = maxQuant > absQuant[quant_chunk_idx+2] ? maxQuant : absQuant[quant_chunk_idx+2];

            // For the .w element, get quantization, lorenzo prediction, get and combine sign info, get absolute value, and update max quant.
            currQuant = quantization(tmp_buffer.w, recipPrecision);
            lorenQuant = currQuant - prevQuant;
            prevQuant = currQuant;
            sign_ofs = (i+3) % 32;
            sign_flag[j+3] |= (lorenQuant < 0) << (31 - sign_ofs);
            absQuant[quant_chunk_idx+3] = abs(lorenQuant);
            maxQuant = maxQuant > absQuant[quant_chunk_idx+3] ? maxQuant : absQuant[quant_chunk_idx+3];
        }

        // Fourth block: record info.
        fixed_rate[j+3] = get_bit_num(maxQuant);
        thread_ofs += (fixed_rate[j+3]) ? (4+fixed_rate[j+3]*4) : 0;
        tmp_char.w = (unsigned char)fixed_rate[j+3];
        __syncthreads();

        // Write block fixed rate to compressed data.
        reinterpret_cast<uchar4*>(cmpData)[block_idx/4] = tmp_char;
        __syncthreads();
    }

    // Warp-level prefix-sum (inclusive), also thread-block-level.
    #pragma unroll 5
    for(int i=1; i<32; i<<=1)
    {
        int tmp = __shfl_up_sync(0xffffffff, thread_ofs, i);
        if(lane >= i) thread_ofs += tmp;
    }
    __syncthreads();

    // Write warp(i.e. thread-block)-level prefix-sum to global-memory.
    if(lane==31) 
    {
        locOffset[warp+1] = thread_ofs;
        __threadfence();
        if(warp==0)
        {
            flag[0] = 2;
            __threadfence();
            flag[1] = 1;
            __threadfence();
        }
        else
        {
            flag[warp+1] = 1;
            __threadfence();    
        }
    }
    __syncthreads();

    // Global-level prefix-sum (exclusive).
    if(warp>0)
    {
        if(!lane)
        {
            // Decoupled look-back
            int lookback = warp;
            int loc_excl_sum = 0;
            while(lookback>0)
            {
                int status;
                // Local sum not end.
                do{
                    status = flag[lookback];
                    __threadfence();
                } while (status==0);
                // Lookback end.
                if(status==2)
                {
                    loc_excl_sum += cmpOffset[lookback];
                    __threadfence();
                    break;
                }
                // Continues lookback.
                if(status==1) loc_excl_sum += locOffset[lookback];
                lookback--;
                __threadfence();
            }
            excl_sum = loc_excl_sum;
        }
        __syncthreads();
    }
    
    if(warp>0)
    {
        // Update global flag.
        if(!lane) cmpOffset[warp] = excl_sum;
        __threadfence();
        if(!lane) flag[warp] = 2;
        __threadfence();  
    }
    __syncthreads();
    
    // Assigning compression bytes by given prefix-sum results.
    if(!lane) base_idx = excl_sum + rate_ofs;
    __syncthreads();

    // Bit shuffle for each index, also storing data to global memory.
    unsigned int base_cmp_byte_ofs = base_idx;
    unsigned int cmp_byte_ofs;
    unsigned int tmp_byte_ofs = 0;
    unsigned int cur_byte_ofs = 0;
    for(int j=0; j<block_num; j++)
    {
        int chunk_idx_start = j*32;

        // Restore index for j-th iteration.
        tmp_byte_ofs = (fixed_rate[j]) ? (4+fixed_rate[j]*4) : 0;
        #pragma unroll 5
        for(int i=1; i<32; i<<=1)
        {
            int tmp = __shfl_up_sync(0xffffffff, tmp_byte_ofs, i);
            if(lane >= i) tmp_byte_ofs += tmp;
        }
        unsigned int prev_thread = __shfl_up_sync(0xffffffff, tmp_byte_ofs, 1);
        if(!lane) cmp_byte_ofs = base_cmp_byte_ofs + cur_byte_ofs;
        else cmp_byte_ofs = base_cmp_byte_ofs + cur_byte_ofs + prev_thread;

        // Operation for each block, if zero block then do nothing.
        if(fixed_rate[j])
        {
            // Assign sign information for one block.
            tmp_char.x = 0xff & (sign_flag[j] >> 24);
            tmp_char.y = 0xff & (sign_flag[j] >> 16);
            tmp_char.z = 0xff & (sign_flag[j] >> 8);
            tmp_char.w = 0xff & sign_flag[j];
            reinterpret_cast<uchar4*>(cmpData)[cmp_byte_ofs/4] = tmp_char;
            cmp_byte_ofs+=4;

            // Assign quant bit information for one block by bit-shuffle.
            int mask = 1;
            for(int i=0; i<fixed_rate[j]; i++)
            {
                // Initialization.
                tmp_char.x = 0;
                tmp_char.y = 0;
                tmp_char.z = 0;
                tmp_char.w = 0;

                // Get ith bit in 0~7 quant, and store to tmp_char.x
                tmp_char.x = (((absQuant[chunk_idx_start+0] & mask) >> i) << 7) |
                             (((absQuant[chunk_idx_start+1] & mask) >> i) << 6) |
                             (((absQuant[chunk_idx_start+2] & mask) >> i) << 5) |
                             (((absQuant[chunk_idx_start+3] & mask) >> i) << 4) |
                             (((absQuant[chunk_idx_start+4] & mask) >> i) << 3) |
                             (((absQuant[chunk_idx_start+5] & mask) >> i) << 2) |
                             (((absQuant[chunk_idx_start+6] & mask) >> i) << 1) |
                             (((absQuant[chunk_idx_start+7] & mask) >> i) << 0);

                // Get ith bit in 8~15 quant, and store to tmp_char.y
                tmp_char.y = (((absQuant[chunk_idx_start+8] & mask) >> i) << 7) |
                             (((absQuant[chunk_idx_start+9] & mask) >> i) << 6) |
                             (((absQuant[chunk_idx_start+10] & mask) >> i) << 5) |
                             (((absQuant[chunk_idx_start+11] & mask) >> i) << 4) |
                             (((absQuant[chunk_idx_start+12] & mask) >> i) << 3) |
                             (((absQuant[chunk_idx_start+13] & mask) >> i) << 2) |
                             (((absQuant[chunk_idx_start+14] & mask) >> i) << 1) |
                             (((absQuant[chunk_idx_start+15] & mask) >> i) << 0);

                // Get ith bit in 16~23 quant, and store to tmp_char.z
                tmp_char.z = (((absQuant[chunk_idx_start+16] & mask) >> i) << 7) |
                             (((absQuant[chunk_idx_start+17] & mask) >> i) << 6) |
                             (((absQuant[chunk_idx_start+18] & mask) >> i) << 5) |
                             (((absQuant[chunk_idx_start+19] & mask) >> i) << 4) |
                             (((absQuant[chunk_idx_start+20] & mask) >> i) << 3) |
                             (((absQuant[chunk_idx_start+21] & mask) >> i) << 2) |
                             (((absQuant[chunk_idx_start+22] & mask) >> i) << 1) |
                             (((absQuant[chunk_idx_start+23] & mask) >> i) << 0);
                
                // Get ith bit in 24-31 quant, and store to tmp_char.w
                tmp_char.w = (((absQuant[chunk_idx_start+24] & mask) >> i) << 7) |
                             (((absQuant[chunk_idx_start+25] & mask) >> i) << 6) |
                             (((absQuant[chunk_idx_start+26] & mask) >> i) << 5) |
                             (((absQuant[chunk_idx_start+27] & mask) >> i) << 4) |
                             (((absQuant[chunk_idx_start+28] & mask) >> i) << 3) |
                             (((absQuant[chunk_idx_start+29] & mask) >> i) << 2) |
                             (((absQuant[chunk_idx_start+30] & mask) >> i) << 1) |
                             (((absQuant[chunk_idx_start+31] & mask) >> i) << 0);

                // Move data to global memory via a vectorized pattern.
                reinterpret_cast<uchar4*>(cmpData)[cmp_byte_ofs/4] = tmp_char;
                cmp_byte_ofs+=4;
                mask <<= 1;
            }
        }

        // Index updating across different iterations.
        cur_byte_ofs += __shfl_sync(0xffffffff, tmp_byte_ofs, 31);
    }
}

 /** ************************************************************************
 * @brief GSZ decompression kernel
 *
 * @param   decData         output reconstructed data array
 * @param   cmpData         compressed data array
 * @param   cmpOffset       output global device-scan
 * @param   locOffset       input local device-scan
 * @param   flag            flags for device-scan
 * @param   eb              user-defined error bound
 * @param   nbEle           original data size (number of floating point)
 * *********************************************************************** */
__global__ void GSZ_decompress_kernel(float* const __restrict__ decData, 
                                      const unsigned char* const __restrict__ cmpData, 
                                      volatile unsigned int* const __restrict__ cmpOffset, 
                                      volatile unsigned int* const __restrict__ locOffset, 
                                      volatile int* const __restrict__ flag, 
                                      const float eb, const size_t nbEle)
{
    __shared__ unsigned int excl_sum;
    __shared__ unsigned int base_idx;

    const int tid = threadIdx.x;
    const int bid = blockIdx.x;
    const int idx = bid * blockDim.x + tid;
    const int lane = idx & 0x1f;
    const int warp = idx >> 5;
    const int block_num = dec_chunk >> 5;
    const int rate_ofs = (nbEle+dec_tblock_size*dec_chunk-1)/(dec_tblock_size*dec_chunk)*(dec_tblock_size*dec_chunk)/32;

    int base_start_idx;
    int base_block_start_idx;
    int block_idx;    
    int absQuant[32];
    int currQuant, lorenQuant, prevQuant;
    int sign_ofs;
    int fixed_rate[block_num];
    unsigned int thread_ofs = 0;
    uchar4 tmp_char;
    float4 dec_buffer;

    // Obtain fixed rate information for each block.
    // Accessing data via a vectorized manner.
    for(int j=0; j<block_num; j+=4)
    {
        // Retrieve data.
        block_idx = warp * dec_chunk + j * 32 + lane * 4;
        tmp_char = reinterpret_cast<const uchar4*>(cmpData)[block_idx/4];
        
        // Assign data to the first block.
        fixed_rate[j] = (int)tmp_char.x;
        thread_ofs += (fixed_rate[j]) ? (4+fixed_rate[j]*4) : 0;

        // Assign data to the second block.
        fixed_rate[j+1] = (int)tmp_char.y;
        thread_ofs += (fixed_rate[j+1]) ? (4+fixed_rate[j+1]*4) : 0;

        // Assign data to the third block.
        fixed_rate[j+2] = (int)tmp_char.z;
        thread_ofs += (fixed_rate[j+2]) ? (4+fixed_rate[j+2]*4) : 0;

        // Assign data to the fourth block.
        fixed_rate[j+3] = (int)tmp_char.w;
        thread_ofs += (fixed_rate[j+3]) ? (4+fixed_rate[j+3]*4) : 0;
        __syncthreads();
    }

    // Warp-level prefix-sum (inclusive), also thread-block-level.
    #pragma unroll 5
    for(int i=1; i<32; i<<=1)
    {
        int tmp = __shfl_up_sync(0xffffffff, thread_ofs, i);
        if(lane >= i) thread_ofs += tmp;
    }
    __syncthreads();

    // Write warp(i.e. thread-block)-level prefix-sum to global-memory.
    if(lane==31) 
    {
        locOffset[warp+1] = thread_ofs;
        __threadfence();
        if(warp==0)
        {
            flag[0] = 2;
            __threadfence();
            flag[1] = 1;
            __threadfence();
        }
        else
        {
            flag[warp+1] = 1;
            __threadfence();    
        }
    }
    __syncthreads();

    // Global-level prefix-sum (exclusive).
    if(warp>0)
    {
        if(!lane)
        {
            // Decoupled look-back
            int lookback = warp;
            int loc_excl_sum = 0;
            while(lookback>0)
            {
                int status;
                // Local sum not end.
                do{
                    status = flag[lookback];
                    __threadfence();
                } while (status==0);
                // Lookback end.
                if(status==2)
                {
                    loc_excl_sum += cmpOffset[lookback];
                    __threadfence();
                    break;
                }
                // Continues lookback.
                if(status==1) loc_excl_sum += locOffset[lookback];
                lookback--;
                __threadfence();
            }
            excl_sum = loc_excl_sum;
        }
        __syncthreads();
    }
    
    if(warp>0)
    {
        // Update global flag.
        if(!lane) cmpOffset[warp] = excl_sum;
        __threadfence();
        if(!lane) flag[warp] = 2;
        __threadfence();  
    }
    __syncthreads();

    // Retrieving compression bytes and reconstruct decompression data.
    if(!lane) base_idx = excl_sum + rate_ofs;
    __syncthreads();

    // Restore bit-shuffle for each block.
    unsigned int base_cmp_byte_ofs = base_idx;
    unsigned int cmp_byte_ofs;
    unsigned int tmp_byte_ofs = 0;
    unsigned int cur_byte_ofs = 0;
    base_start_idx = warp * dec_chunk * 32;
    for(int j=0; j<block_num; j++)
    {
        // Block initialization.
        base_block_start_idx = base_start_idx + j * 1024 + lane * 32;
        unsigned int sign_flag = 0;

        // Restore index for j-th iteration.
        tmp_byte_ofs = (fixed_rate[j]) ? (4+fixed_rate[j]*4) : 0;
        #pragma unroll 5
        for(int i=1; i<32; i<<=1)
        {
            int tmp = __shfl_up_sync(0xffffffff, tmp_byte_ofs, i);
            if(lane >= i) tmp_byte_ofs += tmp;
        }
        unsigned int prev_thread = __shfl_up_sync(0xffffffff, tmp_byte_ofs, 1);
        if(!lane) cmp_byte_ofs = base_cmp_byte_ofs + cur_byte_ofs;
        else cmp_byte_ofs = base_cmp_byte_ofs + cur_byte_ofs + prev_thread;

        // Operation for each block, if zero block then do nothing.
        if(fixed_rate[j])
        {
            // Retrieve sign information for one block.
            tmp_char = reinterpret_cast<const uchar4*>(cmpData)[cmp_byte_ofs/4];
            sign_flag = (0xff000000 & (tmp_char.x << 24)) |
                        (0x00ff0000 & (tmp_char.y << 16)) |
                        (0x0000ff00 & (tmp_char.z << 8))  |
                        (0x000000ff & tmp_char.w);
            cmp_byte_ofs+=4;
            
            // Retrieve quant data for one block.
            for(int i=0; i<32; i++) absQuant[i] = 0;
            for(int i=0; i<fixed_rate[j]; i++)
            {
                // Initialization.
                tmp_char = reinterpret_cast<const uchar4*>(cmpData)[cmp_byte_ofs/4];
                cmp_byte_ofs+=4;

                // Get ith bit in 0~7 abs quant from global memory.
                absQuant[0] |= ((tmp_char.x >> 7) & 0x00000001) << i;
                absQuant[1] |= ((tmp_char.x >> 6) & 0x00000001) << i;
                absQuant[2] |= ((tmp_char.x >> 5) & 0x00000001) << i;
                absQuant[3] |= ((tmp_char.x >> 4) & 0x00000001) << i;
                absQuant[4] |= ((tmp_char.x >> 3) & 0x00000001) << i;
                absQuant[5] |= ((tmp_char.x >> 2) & 0x00000001) << i;
                absQuant[6] |= ((tmp_char.x >> 1) & 0x00000001) << i;
                absQuant[7] |= ((tmp_char.x >> 0) & 0x00000001) << i;

                // Get ith bit in 8~15 abs quant from global memory.
                absQuant[8] |= ((tmp_char.y >> 7) & 0x00000001) << i;
                absQuant[9] |= ((tmp_char.y >> 6) & 0x00000001) << i;
                absQuant[10] |= ((tmp_char.y >> 5) & 0x00000001) << i;
                absQuant[11] |= ((tmp_char.y >> 4) & 0x00000001) << i;
                absQuant[12] |= ((tmp_char.y >> 3) & 0x00000001) << i;
                absQuant[13] |= ((tmp_char.y >> 2) & 0x00000001) << i;
                absQuant[14] |= ((tmp_char.y >> 1) & 0x00000001) << i;
                absQuant[15] |= ((tmp_char.y >> 0) & 0x00000001) << i;

                // Get ith bit in 16-23 abs quant from global memory.
                absQuant[16] |= ((tmp_char.z >> 7) & 0x00000001) << i;
                absQuant[17] |= ((tmp_char.z >> 6) & 0x00000001) << i;
                absQuant[18] |= ((tmp_char.z >> 5) & 0x00000001) << i;
                absQuant[19] |= ((tmp_char.z >> 4) & 0x00000001) << i;
                absQuant[20] |= ((tmp_char.z >> 3) & 0x00000001) << i;
                absQuant[21] |= ((tmp_char.z >> 2) & 0x00000001) << i;
                absQuant[22] |= ((tmp_char.z >> 1) & 0x00000001) << i;
                absQuant[23] |= ((tmp_char.z >> 0) & 0x00000001) << i;

                // Get ith bit in 24-31 abs quant from global memory.
                absQuant[24] |= ((tmp_char.w >> 7) & 0x00000001) << i;
                absQuant[25] |= ((tmp_char.w >> 6) & 0x00000001) << i;
                absQuant[26] |= ((tmp_char.w >> 5) & 0x00000001) << i;
                absQuant[27] |= ((tmp_char.w >> 4) & 0x00000001) << i;
                absQuant[28] |= ((tmp_char.w >> 3) & 0x00000001) << i;
                absQuant[29] |= ((tmp_char.w >> 2) & 0x00000001) << i;
                absQuant[30] |= ((tmp_char.w >> 1) & 0x00000001) << i;
                absQuant[31] |= ((tmp_char.w >> 0) & 0x00000001) << i;
            }
            
            // Delorenzo and store data back to decompression data.
            prevQuant = 0;
            #pragma unroll 8
            for(int i=0; i<32; i+=4)
            {
                // For the .x element, reconstruct sign (absolute value), lorenzo quantization, quantization, and original value.
                sign_ofs = i % 32;
                lorenQuant = sign_flag & (1 << (31 - sign_ofs)) ? absQuant[i] * -1 : absQuant[i];
                currQuant = lorenQuant + prevQuant;
                prevQuant = currQuant;
                dec_buffer.x = currQuant * eb * 2;

                // For the .y element, reconstruct sign (absolute value), lorenzo quantization, quantization, and original value.
                sign_ofs = (i+1) % 32;
                lorenQuant = sign_flag & (1 << (31 - sign_ofs)) ? absQuant[i+1] * -1 : absQuant[i+1];
                currQuant = lorenQuant + prevQuant;
                prevQuant = currQuant;
                dec_buffer.y = currQuant * eb * 2;

                // For the .z element, reconstruct sign (absolute value), lorenzo quantization, quantization, and original value.
                sign_ofs = (i+2) % 32;
                lorenQuant = sign_flag & (1 << (31 - sign_ofs)) ? absQuant[i+2] * -1 : absQuant[i+2];
                currQuant = lorenQuant + prevQuant;
                prevQuant = currQuant;
                dec_buffer.z = currQuant * eb * 2;

                // For the .w element, reconstruct sign (absolute value), lorenzo quantization, quantization, and original value.
                sign_ofs = (i+3) % 32;
                lorenQuant = sign_flag & (1 << (31 - sign_ofs)) ? absQuant[i+3] * -1 : absQuant[i+3];
                currQuant = lorenQuant + prevQuant;
                prevQuant = currQuant;
                dec_buffer.w = currQuant * eb * 2;
                
                // Read data from global variable via a vectorized pattern.
                reinterpret_cast<float4*>(decData)[(base_block_start_idx+i)/4] = dec_buffer;
            }            
        }

        // Index updating across different iterations.
        cur_byte_ofs += __shfl_sync(0xffffffff, tmp_byte_ofs, 31);
    }
}

 /** ************************************************************************
 * @brief Pre-quantization for one float point data.
 *        Device function, C code version as backup.
 * 
 * @param   data            input float point data
 * @param   recipPrecision  reciprocal of 2 x user-defined error bound
 *
 * @return  result          quantization integer for the input fp
 * *********************************************************************** */
__device__ inline int quantization_src_backup(float data, float recipPrecision)
{
    float dataRecip = data*recipPrecision;
    int s = dataRecip>=-0.5f?0:1;
    return (int)(dataRecip+0.5f) - s;
}

 /** ************************************************************************
 * @brief Get number of effective bits for a integer.
 *        Device function, C code version as backup.
 * 
 * @param   x                   input integer
 *
 * @return  (32-leading_zeros)  number of effective bits for x
 * *********************************************************************** */
__device__ inline int get_bit_num_src_backup(unsigned int x)
{
    return (sizeof(unsigned int)*8) - __clz(x);
}