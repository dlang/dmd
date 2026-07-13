//ImportC: typeof in initializer expression at function scope errors with "circular typeof definition" #20433


#include <stdio.h>
#include <assert.h>

int x = sizeof(typeof(typeof(x))); // supported in C
int main()
{

    int y = sizeof(typeof(y));
    assert(y == 4);
    assert(x == 4);

}
