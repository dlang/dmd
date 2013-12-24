// PERMUTE_ARGS:

import imports.test70 : foo;
void foo(int) {}
// selective import does not create local alias implicitly

void bar()
{
    static assert(!__traits(compiles, foo()));
    foo(1);
}
