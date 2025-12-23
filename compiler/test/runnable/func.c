#include <assert.h>
#include <string.h>
#include <stdio.h>

void foo()
{
    assert(strcmp(__FUNCTION__, "foo") == 0);
    assert(strstr(__PRETTY_FUNCTION__, "foo")); // make room for runtime differences
}

int bar(int a, int b)
{
    assert(strcmp(__FUNCTION__, "bar") == 0);
    assert(strstr(__PRETTY_FUNCTION__, "bar"));
    return 0;
}

int main()
{
    foo();
    return bar(4, 6);
}
