#include <assert.h>

#include <bennet/rand.h>
#include <bennet/uniform.h>
#include <cn-executable/utils.h>

#define BITS_GEN(sm)                                                                     \
  cn_bits_u##sm* bennet_uniform_cn_bits_u##sm(uint64_t sz) {                             \
    return convert_to_cn_bits_u##sm(bennet_uniform_u##sm##_sized(sz));                   \
  }                                                                                      \
                                                                                         \
  cn_bits_i##sm* bennet_uniform_cn_bits_i##sm(uint64_t sz) {                             \
    return convert_to_cn_bits_i##sm(bennet_uniform_i##sm##_sized(sz));                   \
  }

BITS_GEN(8);
BITS_GEN(16);
BITS_GEN(32);
BITS_GEN(64);

#define RANGE_GEN(sm)                                                                    \
  cn_bits_u##sm* bennet_range_cn_bits_u##sm(cn_bits_u##sm* min, cn_bits_u##sm* max) {    \
    return convert_to_cn_bits_u##sm(bennet_range_u##sm(min->val, max->val));             \
  }                                                                                      \
  cn_bits_i##sm* bennet_range_cn_bits_i##sm(cn_bits_i##sm* min, cn_bits_i##sm* max) {    \
    return convert_to_cn_bits_i##sm(bennet_range_i##sm(min->val, max->val));             \
  }

RANGE_GEN(8);
RANGE_GEN(16);
RANGE_GEN(32);
RANGE_GEN(64);

#define INEQ_GEN(sm)                                                                     \
  cn_bits_u##sm* bennet_lt_cn_bits_u##sm(cn_bits_u##sm* max) {                           \
    return convert_to_cn_bits_u##sm(bennet_lt_u##sm(max->val));                          \
  }                                                                                      \
  cn_bits_i##sm* bennet_lt_cn_bits_i##sm(cn_bits_i##sm* max) {                           \
    return convert_to_cn_bits_i##sm(bennet_lt_i##sm(max->val));                          \
  }                                                                                      \
  cn_bits_u##sm* bennet_ge_cn_bits_u##sm(cn_bits_u##sm* min) {                           \
    return convert_to_cn_bits_u##sm(bennet_ge_u##sm(min->val));                          \
  }                                                                                      \
  cn_bits_i##sm* bennet_ge_cn_bits_i##sm(cn_bits_i##sm* min) {                           \
    return convert_to_cn_bits_i##sm(bennet_ge_i##sm(min->val));                          \
  }

INEQ_GEN(8);
INEQ_GEN(16);
INEQ_GEN(32);
INEQ_GEN(64);

#define MULT_RANGE_GEN(sm)                                                               \
  cn_bits_u##sm* bennet_mult_range_cn_bits_u##sm(                                        \
      cn_bits_u##sm* mul, cn_bits_u##sm* min, cn_bits_u##sm* max) {                      \
    return convert_to_cn_bits_u##sm(                                                     \
        bennet_mult_range_u##sm(mul->val, min->val, max->val));                          \
  }                                                                                      \
  cn_bits_i##sm* bennet_mult_range_cn_bits_i##sm(                                        \
      cn_bits_i##sm* mul, cn_bits_i##sm* min, cn_bits_i##sm* max) {                      \
    return convert_to_cn_bits_i##sm(                                                     \
        bennet_mult_range_i##sm(mul->val, min->val, max->val));                          \
  }

MULT_RANGE_GEN(8);
MULT_RANGE_GEN(16);
MULT_RANGE_GEN(32);
MULT_RANGE_GEN(64);

#define MULT_GEN(sm)                                                                     \
  cn_bits_u##sm* bennet_mult_cn_bits_u##sm(cn_bits_u##sm* mul) {                         \
    return convert_to_cn_bits_u##sm(bennet_mult_u##sm(mul->val));                        \
  }                                                                                      \
  cn_bits_i##sm* bennet_mult_cn_bits_i##sm(cn_bits_i##sm* mul) {                         \
    return convert_to_cn_bits_i##sm(bennet_mult_i##sm(mul->val));                        \
  }

MULT_GEN(8);
MULT_GEN(16);
MULT_GEN(32);
MULT_GEN(64);
