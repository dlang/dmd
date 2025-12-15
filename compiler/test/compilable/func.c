#include <assert.h>
#include <string.h>
void foo()
{
    assert(strcmp(__FUNCTION__, "foo") == 0);
    assert(strcmp(__PRETTY_FUNCTION__, "func.foo") == 0);
}

int main()
{
    foo();
}
