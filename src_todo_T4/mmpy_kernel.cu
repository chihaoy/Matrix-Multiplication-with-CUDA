// ;-*- mode: c;-*-
// Matrix multiply device code
#include <assert.h>
#include <math.h>
#include "../src/utils.h"
#include "../src/types.h"
#include "mytypes.h"
using namespace std;

#include <stdio.h>

#if NAIVE == 1
__global__ void matMul(int N, _FTYPE_ *C, _FTYPE_ *A, _FTYPE_ *B) {

    int I =  blockIdx.y*blockDim.y + threadIdx.y;
    int J =  blockIdx.x*blockDim.x + threadIdx.x;
    // printf("blockIdx.y: %d, blockIdx.x %d\n", blockIdx.y, blockIdx.x);
    // printf("blockDim.y: %d, blockDim.x: %d\n", blockDim.y, blockDim.x);
    
    if((I < N) && (J < N)){
        _FTYPE_ _c = 0;
        PRAGMA_UNROLL
        for (unsigned int k = 0; k < N; k++) {
            _FTYPE_ a = A[I * N + k];
            _FTYPE_ b = B[k * N + J];
            _c += a * b;
        }
        C[I * N + J] = _c;
    }
}
#elif BASIC_SHM == 1
//You should be changing the kernel here for the non naive implementation.
__global__ void matMul(int N, _FTYPE_ *C, _FTYPE_ *A, _FTYPE_ *B) {

    extern __shared__ _FTYPE_ sharedMem[]; //use dynamic shared mem
    _FTYPE_ *As = sharedMem;
    _FTYPE_ *Bs = &sharedMem[BLOCK_SIZE * BLOCK_SIZE];

    _FTYPE_ Cij = 0.0;

    int ty = threadIdx.y, tx = threadIdx.x;
    int by = blockIdx.y, bx = blockIdx.x;
    int I = by * BLOCK_SIZE + ty;
    int J = bx * BLOCK_SIZE + tx;

    PRAGMA_UNROLL
    for (int kk = 0; kk < N / BLOCK_SIZE; kk++) {
        if (I < N && J < N) {
            As[ty * BLOCK_SIZE + tx] = A[I * N + kk * BLOCK_SIZE + tx];
            Bs[ty * BLOCK_SIZE + tx] = B[(kk * BLOCK_SIZE + ty) * N + J];
        }
       
        __syncthreads();

        PRAGMA_UNROLL
        for (int k = 0; k < BLOCK_SIZE; k++) {
            Cij += As[ty * BLOCK_SIZE + k] * Bs[k * BLOCK_SIZE + tx];
        }

        __syncthreads();
    }
    if (I < N && J < N) {
        C[I * N + J] = Cij;
    }
    //C[I * N + J] = Cij;
}    

#elif TILING == 1
//You should be changing the kernel here for the non naive implementation.
__global__ void matMul(int N, _FTYPE_ *C, _FTYPE_ *A, _FTYPE_ *B) {

    extern __shared__ _FTYPE_ sharedMem[]; // use dynamic shared memory
    _FTYPE_ *As = sharedMem; // size: TILEDIM_M * TILEDIM_K
    _FTYPE_ *Bs = &sharedMem[TILEDIM_M * TILEDIM_K]; // size: TILEDIM_K * TILEDIM_N

    _FTYPE_ Cij[TILESCALE_M][TILESCALE_N] = {0.0};
    #if PRE_LOAD_CIJ == 1
    register _FTYPE_ Ci_reg[TILESCALE_M] = {0.0};
    register _FTYPE_ Cj_reg[TILESCALE_N] = {0.0};
    #endif

    const int tx = threadIdx.x, ty = threadIdx.y;
    const int bx = blockIdx.x, by = blockIdx.y;
    const int I = (by * blockDim.y + ty) * TILESCALE_M;
    const int J = (bx * blockDim.x + tx) * TILESCALE_N;

    const int threadID = threadIdx.y * blockDim.x + threadIdx.x;

    const int tileRowA = threadID / TILEDIM_K;
    const int tileColA = threadID % TILEDIM_K;
    const int tileRowB = threadID / TILEDIM_N;
    const int tileColB = threadID % TILEDIM_N;

    const int strideA = (BLOCKDIM_X * BLOCKDIM_Y) / TILEDIM_K;
    const int strideB = (BLOCKDIM_X * BLOCKDIM_Y) / TILEDIM_N;

    PRAGMA_UNROLL
    for (int kk = 0; kk < N; kk += TILEDIM_K) {
        // load submatrix A into shared memory
        PRAGMA_UNROLL
        for (int i = 0; i < TILEDIM_M; i += strideA) {
            const int row = tileRowA + TILEDIM_M * by + i;
            const int col = tileColA + kk;
            #if USE_IF_STATEMENT == 0
            As[(tileRowA + i) * TILEDIM_K + tileColA] = (row < N && col < N)? A[row * N + col] : 0;
            #else
            if (row < N && col < N) {
                As[(tileRowA + i) * TILEDIM_K + tileColA] = A[row * N + col];
            }
            #endif
        }

        // load submatrix B into shared memory
        PRAGMA_UNROLL
        for (int i = 0; i < TILEDIM_K; i += strideB) {
            const int row = tileRowB + kk + i;
            const int col = tileColB + TILEDIM_N * bx;
            #if USE_IF_STATEMENT == 0
            Bs[(tileRowB + i) * TILEDIM_N + tileColB] = (row < N && col < N)? B[row * N + col] : 0;
            #else
            if (row < N && col < N) {
                Bs[(tileRowB + i) * TILEDIM_N + tileColB] = B[row * N + col];
            }
            #endif
        }   
        __syncthreads();

        PRAGMA_UNROLL
        for (int k = 0; k < TILEDIM_K; ++k) {
            #if PRE_LOAD_CIJ == 1
            // Preload shared memory into register
            PRAGMA_UNROLL
            for (int i = 0; i < TILESCALE_M; ++i) {
                Ci_reg[i] = As[(TILESCALE_M * ty + i) * TILEDIM_K + k]; // As[TILESCALE_M * ty + i][k]
            }

            PRAGMA_UNROLL
            for (int i = 0; i < TILESCALE_N; ++i) {
                Cj_reg[i] = Bs[k * TILEDIM_N + TILESCALE_N * tx + i]; // Bs[k][TILESCALE_N * tx + i]
            }

            // Calculate submatrix C
            PRAGMA_UNROLL
            for (int i = 0; i < TILESCALE_M; ++i) {
                PRAGMA_UNROLL
                for (int j = 0; j < TILESCALE_N; ++j) {
                    Cij[i][j] += Ci_reg[i] * Cj_reg[j];
                }
            }
            #else
            // Calculate submatrix C
            PRAGMA_UNROLL
            for (int i = 0; i < TILESCALE_M; ++i) {
                PRAGMA_UNROLL
                for (int j = 0; j < TILESCALE_N; ++j) {

                    Cij[i][j] += As[(TILESCALE_M * ty + i) * TILEDIM_K + k] 
                                * Bs[k * TILEDIM_N + TILESCALE_N * tx + j];
                }
            } 
            #endif
        }

        __syncthreads();
    }

    // Calculate C
    PRAGMA_UNROLL
    for (int i = 0; i < TILESCALE_M; i++) {
        PRAGMA_UNROLL
        for (int j = 0; j < TILESCALE_N; j++) {
            const int row = I + i;
            const int col = J + j;
            if (row < N && col < N) {
                C[row * N + col] = Cij[i][j];
            }
            //C[row * N + col] = Cij[i][j];
        }
    }
}
#endif