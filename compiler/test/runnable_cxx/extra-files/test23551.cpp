#include "test23551.h"
#include <stdio.h>

Base::Base()
{
}
int Base::f()
{
    return 1000 + i;
}

C::C()
{
}
int C::g()
{
    return 3000 + i;
}

E::E()
{
}
int E::g2()
{
    return 5200 + i;
}
int E::g3()
{
    return 5300 + i;
}
int E::g4()
{
    return 5400 + i;
}
int E::g5()
{
    return 5500 + i;
}
