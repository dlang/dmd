#include <complex.h>

void foo(_Complex double z)
{
    return;
}


int main()
{
    double z;
    foo(z);
}
