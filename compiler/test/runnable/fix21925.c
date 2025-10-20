//https://github.com/dlang/dmd/issues/21925

#include <assert.h>
int a;
int a;
int a;
int a;
int a;


int main()
{
    assert(a == 0); // no duplicate symbol error
}
