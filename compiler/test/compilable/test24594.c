#include <stdint.h>

struct S1
{
  uint32_t a;
  uint64_t b;
} __attribute__((packed));

_Static_assert(sizeof(S1) == 12, "S1 size");
_Static_assert(&((struct S1*)0)->b == 4, "S1::b offset");

struct __attribute__((packed)) S2
{
  uint8_t a;
  uint16_t b;
};

_Static_assert(sizeof(S2) == 3, "S2 size");
_Static_assert(&((struct S2*)0)->b == 1, "S2::b offset");

struct __attribute__((packed)) S3
{
  uint32_t a;
  uint8_t b;
};

_Static_assert(sizeof(S3) == 5, "S3 size");
_Static_assert(&((struct S3*)0)->b == 4, "S3::b offset");
