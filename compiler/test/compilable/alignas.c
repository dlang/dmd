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

// __declspec(align(N)) behaves like __attribute__((aligned(N))): only increases alignment
// N < natural (4): ignored
struct __declspec(align(2)) S3 { int x; };
_Static_assert(sizeof(struct S3) == 4, "sizeof S3");
_Static_assert(_Alignof(struct S3) == 4, "alignof S3");

// N > natural (4): increases to 16
struct __declspec(align(16)) S4 { int x; };
_Static_assert(sizeof(struct S4) == 16, "sizeof S4");
_Static_assert(_Alignof(struct S4) == 16, "alignof S4");

// #pragma pack reduces alignment (unlike aligned), so it must still work
#pragma pack(2)
struct S5 { int x; };
#pragma pack()
_Static_assert(_Alignof(struct S5) == 2, "alignof S5");

// Combinations of #pragma pack with alignment attributes
// pack(2) + aligned(8): pack reduces member alignment, aligned(8) still increases struct alignment (matches GCC)
#pragma pack(2)
struct S6 { int x; } __attribute__((aligned(8)));
#pragma pack()
_Static_assert(sizeof(struct S6) == 8, "sizeof S6");
_Static_assert(_Alignof(struct S6) == 8, "alignof S6");

// pack(2) + __declspec(align(8)): same result as above
#pragma pack(2)
struct __declspec(align(8)) S7 { int x; };
#pragma pack()
_Static_assert(sizeof(struct S7) == 8, "sizeof S7");
_Static_assert(_Alignof(struct S7) == 8, "alignof S7");

// pack(2) + aligned(1) on short: aligned(1) < pack's alignsize(2), so ignored
#pragma pack(2)
struct S8 { short x; } __attribute__((aligned(1)));
#pragma pack()
_Static_assert(sizeof(struct S8) == 2, "sizeof S8");
_Static_assert(_Alignof(struct S8) == 2, "alignof S8");

// pack(2) + _Alignas(8) on member: #pragma pack dominates _Alignas (matches GCC)
#pragma pack(2)
struct S9 { _Alignas(8) int x; };
#pragma pack()
_Static_assert(sizeof(struct S9) == 4, "sizeof S9");
_Static_assert(_Alignof(struct S9) == 2, "alignof S9");

// pack(2) + aligned(8) on member: #pragma pack dominates __attribute__((aligned)) (matches GCC/clang)
#pragma pack(2)
struct S10 { int x __attribute__((aligned(8))); };
#pragma pack()
_Static_assert(sizeof(struct S10) == 4, "sizeof S10");
_Static_assert(_Alignof(struct S10) == 2, "alignof S10");

// pack(2) + __declspec(align(8)) on member: #pragma pack dominates (matches clang -fdeclspec)
#pragma pack(2)
struct S11 { __declspec(align(8)) int x; };
#pragma pack()
_Static_assert(sizeof(struct S11) == 4, "sizeof S11");
_Static_assert(_Alignof(struct S11) == 2, "alignof S11");
