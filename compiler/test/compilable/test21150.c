// https://github.com/dlang/dmd/issues/21150

struct S
{
        char            z[16][256];
} __attribute__((aligned(_Alignof(unsigned int))));
_Static_assert(_Alignof(struct S) == _Alignof(unsigned int), "S");

struct T {
    _Static_assert(1, "");
    char x;
} __attribute__((aligned(_Alignof(struct S))));

_Static_assert(_Alignof(struct T) == _Alignof(unsigned int), "T");


struct __attribute__ ((aligned(8))) Q {
    short f[3];
};
_Static_assert(sizeof(struct Q) == 8, "Q1");
_Static_assert(_Alignof(struct Q) == 8, "Q2");


struct __attribute__ ((aligned(8))) R {
    short f[3];
    char c;
};
_Static_assert(sizeof(struct R) == 8, "R1");
_Static_assert(_Alignof(struct R) == 8, "R2");

struct C {
    unsigned _Alignas(2) _Alignas(4) char c;
}
__attribute__((aligned(8)));

_Static_assert(_Alignof(struct C)==8, "C");

struct __attribute__((aligned(4))) D {
    unsigned char c;
}
__attribute__((aligned(8)));

_Static_assert(_Alignof(struct D)==8, "D");
//
// Interaction of aligned() and packed
//
#include <stddef.h>
 struct Spacked {
     unsigned a;
     unsigned long long b;
 } __attribute__((aligned(4), packed));
_Static_assert(_Alignof(struct Spacked) == 4, "Spacked");
_Static_assert(_Alignof(struct Spacked) == 4, "Spacked");
_Static_assert(offsetof(struct Spacked, a) == 0, "Spacked.a");
_Static_assert(offsetof(struct Spacked, b) == sizeof(unsigned), "Spacked.b");
_Static_assert(sizeof(struct Spacked) == sizeof(unsigned) + sizeof(unsigned long long), "sizeof(Spacked)");

struct __attribute__((aligned(4))) Spacked2 {
    unsigned a;
    unsigned long long b;
} __attribute__((packed));
_Static_assert(_Alignof(struct Spacked2) == 4, "Spacked2");
_Static_assert(offsetof(struct Spacked2, a) == 0, "Spacked2.a");
_Static_assert(offsetof(struct Spacked2, b) == sizeof(unsigned), "Spacked2.b");
_Static_assert(sizeof(struct Spacked2) == sizeof(unsigned) + sizeof(unsigned long long), "sizeof(Spacked2)");

#pragma pack(push)
#pragma pack(1)
struct __attribute__((aligned(4))) Spacked3 {
    unsigned a;
    unsigned long long b;
};
#pragma pack(pop)
_Static_assert(_Alignof(struct Spacked3) == 4, "Spacked3");
_Static_assert(offsetof(struct Spacked3, a) == 0, "Spacked3.a");
_Static_assert(offsetof(struct Spacked3, b) == sizeof(unsigned), "Spacked3.b");
_Static_assert(sizeof(struct Spacked3) == sizeof(unsigned) + sizeof(unsigned long long), "sizeof(Spacked3)");
