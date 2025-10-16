//importC: symbol duplication in symbol table for global redeclared symbols #21925
#include <assert.h>
int a;
int a;
int a;
int a;
int a;
int a;


int main()
{
    assert(a == 0); // no duplicate symbol error
    return 0;
}
