// DISABLED: win32 win64

// https://github.com/dlang/dmd/issues/22259

#include <complex.h>
#include <stdio.h>
#include <assert.h>

void foo()
{
    _Complex double x = 1 + 1.0if;
    assert(creal(x) == 1.000000);
    assert(cimag(x) == 1.000000);
    return;
}


int main()
{
    foo();
    return 0;
}
