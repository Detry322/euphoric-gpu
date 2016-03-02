#include "./step_a.h"
#include "./sha_calculate.h"
#include <stdint.h>
#include <assert.h>

__shared__ sha_base base;

__device__ uint64_t calculate_sha(uint64_t nonce) {
  uint32_t work[64];
  uint32_t A, B, C, D, E, F, G, H, t1, t2;
  #pragma unroll
  for (int i = 0; i < 16; i++)
    work[i] = base.work[i];
  A = base.h[0];
  B = base.h[1];
  C = base.h[2];
  D = base.h[3];
  E = base.h[4];
  F = base.h[5];
  G = base.h[6];
  H = base.h[7];
  insert_long_big_endian(nonce, work, 4);
  SHA_CALCULATE(work, A, B, C, D, E, F, G, H);
  return ((((uint64_t) (base.h[6] + G)) << 32) | ((uint64_t) (base.h[7] + H))) & ((1L << base.difficulty) - 1);
}

__device__ void find_solution(two_way_collision* solution, uint64_t nonce_a, uint64_t nonce_b) {
  uint64_t temp_a, temp_b;
  while (true) {
    temp_a = calculate_sha(nonce_a);
    temp_b = calculate_sha(nonce_b);
    if (temp_a == temp_b) {
      solution->nonces[0] = nonce_a;
      solution->nonces[1] = nonce_b;
      return;
    } else {
      nonce_a = temp_a;
      nonce_b = temp_b;
    }
  }
}

__global__ void step_a_kernel(sha_base* input, two_way_collision* solution, uint64_t base_nonce) {
  if (threadIdx.x == 0) {
    base = *input;
  }
  __syncthreads();
  uint64_t initial_nonce = base_nonce + (blockIdx.x*blockDim.x+threadIdx.x);
  uint64_t tortoise, hare;
  tortoise = hare = initial_nonce;
  uint32_t i = 0;
  while (true) {
    i += 1;
    if ((i & 0xFFF) == 0) {
      if (solution->found) {
        return;
      }
    }
    tortoise = calculate_sha(tortoise);
    hare = calculate_sha(calculate_sha(hare));
    if (tortoise == hare) {
      solution->found = true;
      find_solution(solution, initial_nonce, tortoise);
      return;
    }
  }
};