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
