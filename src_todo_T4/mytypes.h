#ifndef MYTYPES_H
#define MYTYPES_H

#ifdef USE_NAIVE
#define NAIVE 1
#define BASIC_SHM 0
#define TILING 0
#elif defined(USE_BASIC_SHM)
#define NAIVE 0
#define BASIC_SHM 1
#define TILING 0
#elif defined(USE_TILING)
#define NAIVE 0
#define BASIC_SHM 0
#define TILING 1
#else
#define NAIVE 0
#define BASIC_SHM 0
#define TILING 1
#endif

#ifndef OPT_UNROLL
#define OPT_UNROLL 1
#endif

#ifndef OPT_REGISTER
#define OPT_REGISTER 1
#endif

#ifndef OPT_BRANCH
#define OPT_BRANCH 1
#endif

#if OPT_UNROLL == 1
#define PRAGMA_UNROLL _Pragma("unroll")
#else
#define PRAGMA_UNROLL
#endif

#if OPT_REGISTER == 1
#define PRE_LOAD_CIJ 1
#else
#define PRE_LOAD_CIJ 0
#endif

#if OPT_BRANCH == 1
#define USE_IF_STATEMENT 0
#else
#define USE_IF_STATEMENT 1
#endif


#if (!defined(BLOCKDIM_X) && !defined(BLOCKDIM_Y))
#define BLOCK_SIZE 8
#define BLOCKDIM_X 8
#define BLOCKDIM_Y 8
#else
#define BLOCK_SIZE BLOCKDIM_X
#endif

// tilescale (# of points computed by each thread)
#ifndef TILESCALE_M
#define TILESCALE_M 8 // Enter your own values
#endif
#ifndef TILESCALE_N
#define TILESCALE_N 8 // Enter your own values
#endif
#ifndef TILESCALE_K
#define TILESCALE_K 4 // Enter your own values
#endif

#define TILEDIM_M (BLOCKDIM_Y * TILESCALE_M) // Enter your own values
#define TILEDIM_N (BLOCKDIM_X * TILESCALE_N) // Enter your own values

// matrix A loads
// with warps along the horiziontal axis (K)
// so to get good coalescaed loads, we want TILEDIM_K to be >= 32
//
#define TILEDIM_K (BLOCKDIM_X * TILESCALE_K) // Enter your own values

// step size in each dimension
#define TILESTEP_N 1 // Enter your own values
#define TILESTEP_K 1 // Enter your own values
#define TILESTEP_M 1 // Enter your own values
 
#endif
