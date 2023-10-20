// https://issues.dlang.org/show_bug.cgi?id=23509

int max(int a, int b)
{
    return ({int _a = (a), _b = (b); _a > _b ? _a : _b; });
}

_Static_assert(max(3,4) == 4, "1");
