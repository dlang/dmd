#include <assert.h>
#include <string.h>
#include <stdio.h>

void foo()
{
    printf("function is %s", __PRETTY_FUNCTION__ );
    assert(strcmp(__FUNCTION__, "foo") == 0);
    assert(strcmp(__PRETTY_FUNCTION__, "void foo()") == 0);

}

int bar(int a, int b)
{
    assert(strcmp(__FUNCTION__, "bar") == 0);
    assert(strcmp(__PRETTY_FUNCTION__, "int bar(int, int)") == 0);
    return 0;
}

int main()
{
    foo();
    return bar(4, 6);
}
