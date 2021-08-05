// Test _Alignas

int printf(const char *, ...);

_Alignas(2) int x = 5;
// not working because of https://issues.dlang.org/show_bug.cgi?22180
//_Static_assert(_Alignof(x) == 4, "in");

_Alignas(long) int y = 6;
// not working because of https://issues.dlang.org/show_bug.cgi?22180
//_Static_assert(_Alignof(x) == 8, "in");

struct S
{
    _Alignas(2) char d;
    _Alignas(int) char c;
};

struct S s = { 1, 2 };
_Static_assert(sizeof(struct S) == 8, "in");
