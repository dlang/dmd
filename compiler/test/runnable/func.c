#include <assert.h>
#include <string.h>
#include <stdio.h>

void foo()
{
    assert(strcmp(__FUNCTION__, "foo") == 0);
    //assert(strcmp(__PRETTY_FUNCTION__, "void foo") == 0);

}

int main()
{
    foo();
}
