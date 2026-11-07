// https://github.com/dlang/dmd/issues/24214
_Static_assert(__alignof__(int) == _Alignof(int), "1");
_Static_assert(__alignof(int) == _Alignof(int), "2");

typedef unsigned long uintptr_t;
typedef struct {
    char c;
} __attribute__ ((aligned (__alignof__ (uintptr_t)))) S1;
typedef struct {
    char c;
} __attribute__ ((aligned (__alignof (uintptr_t)))) S2;
_Static_assert(_Alignof(S1) == _Alignof(uintptr_t), "3");
_Static_assert(_Alignof(S2) == _Alignof(uintptr_t), "4");
