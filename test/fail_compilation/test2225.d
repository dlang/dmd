module test2225;

import imports.test2225;

void foo()
{
    auto o = new Outer;
    o.a = 3;
    auto oi = o.new Inner;
}
