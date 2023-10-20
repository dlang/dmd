// Test _Alignas

int printf(const char *, ...);

_Alignas(4) _Alignas(8) _Alignas(0) int x = 5;
//_Static_assert(_Alignof(x) == 8, "in");

_Alignas(int) short y = 6;
//_Static_assert(_Alignof(y) == 4, "in");

struct S
{
    _Alignas(2) char d;
    _Alignas(int) char c;
};

struct S s = { 1, 2 };
_Static_assert(sizeof(struct S) == 8, "in");
