#include <assert.h>
#include <string.h>
#include <stdio.h>

void foo()
{
    assert(strcmp(__FUNCTION__, "foo") == 0);

#ifndef __linux__
    assert(strcmp(__PRETTY_FUNCTION__, "void foo()") == 0);
#else
    assert(strcmp(__PRETTY_FUNCTION__, "foo") == 0);
#endif

}

int bar(int a, int b)
{
    assert(strcmp(__FUNCTION__, "bar") == 0);
#ifndef __linux__
    assert(strcmp(__PRETTY_FUNCTION__, "int bar(int, int)") == 0);
#else
    assert(strcmp(__PRETTY_FUNCTION__, "bar") == 0);
#endif
    return 0;
}

int main()
{
    foo();
    return bar(4, 6);
}
