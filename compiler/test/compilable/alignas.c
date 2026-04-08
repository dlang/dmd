// Test _Alignas

int printf(const char *, ...);

_Alignas(4) _Alignas(8) _Alignas(0) int x = 5;
_Static_assert(_Alignof(x) == 8, "in");

_Alignas(int) short y = 6;
_Static_assert(_Alignof(y) == 4, "in");

struct S
{
    _Alignas(2) char d;
    _Alignas(int) char c;
};

struct S s = { 1, 2 };
_Static_assert(sizeof(struct S) == 8, "in");

// https://github.com/dlang/dmd/issues/21765
// __attribute__((aligned(N))) can only increase struct alignment

// aligned(2) on struct with int (natural alignment = 4): attribute is ignored, alignment stays 4
struct __attribute__((aligned(2))) S1 { int x; };
_Static_assert(sizeof(struct S1) == 4, "sizeof S1");
_Static_assert(_Alignof(struct S1) == 4, "alignof S1");

// postfix form
struct S2 { int x; } __attribute__((aligned(1)));
_Static_assert(sizeof(struct S2) == 4, "sizeof S2");
_Static_assert(_Alignof(struct S2) == 4, "alignof S2");
