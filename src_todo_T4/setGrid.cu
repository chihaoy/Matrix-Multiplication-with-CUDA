
#include "mytypes.h"
#include <stdio.h>

void setGrid(int n, dim3 &blockDim, dim3 &gridDim)
{

   // set your block dimensions and grid dimensions here
   gridDim.x = n / TILEDIM_N;
   gridDim.y = n / TILEDIM_M;
   //print TILEDIM_N, TILEDIM_M, n, gridDim.x, gridDim.y;
   printf("gridDim.x: %d, gridDim.y: %d\n", gridDim.x, gridDim.y);
   //print TILEDIM_N, TILEDIM_M
   printf("TILEDIM_N: %d, TILEDIM_M: %d\n", TILEDIM_N, TILEDIM_M);
   // you can overwrite blockDim here if you like.
   if (n % TILEDIM_N != 0)
      gridDim.x++;
   if (n % TILEDIM_M != 0)
      gridDim.y++;
}
