// https://issues.dlang.org/show_bug.cgi?id=24181

#include <assert.h>

unsigned equ(double x, double y)
{
    return *(long long *)&x == *(long long *)&y;
}

int main()
{
    assert(equ(1.0, 2.0) == 0);
    assert(equ(527, 527) != 0);
    return 0;
}
