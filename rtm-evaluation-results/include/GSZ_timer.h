#ifndef GSZ_INCLUDE_GSZ_TIMER_H
#define GSZ_INCLUDE_GSZ_TIMER_H

#include <cuda.h>
#include <cuda_runtime.h>

struct PrivateTimingGPU {
    cudaEvent_t start;
    cudaEvent_t stop;
};

class TimingGPU
{
    private:
        PrivateTimingGPU *privateTimingGPU;

    public:

        TimingGPU();

        ~TimingGPU();

        void StartCounter();

        void StartCounterFlags();

        float GetCounter();

};

#endif // GSZ_INCLUDE_GSZ_TIMER_H