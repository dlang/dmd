#include <assert.h>
#include <string.h>
#include <stdio.h>

void foo()
{
    //assert(strcmp(__FUNCTION__, "func.foo") == 0);
    //assert(strcmp(__PRETTY_FUNCTION__, "func.foo") == 0);
    printf("functions is %s\n", __FUNCTION__);
    printf("pretty function is %s\n", __PRETTY_FUNCTION__);

}

int main()
{
    foo();
}
