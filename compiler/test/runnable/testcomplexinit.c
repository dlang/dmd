// DISABLED: win32 win64

#include <complex.h>
#include <stdio.h>
#include <assert.h>

struct com
{
    int r;
    int c;
};

void foo()
{
    struct com obj = { 1, 3};
    _Complex double x = { obj.r, obj.c}; //real + im*i;

    assert(creal(x) == 1.000000);
    assert(cimag(x) == 3.000000);
    return;
}


int main()
{
    foo();
    return 0;
}
