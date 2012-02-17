module test313a;

import imports.test313a;

void foo()
{
    imports.test313priv.foo();
    static assert(0, "FAILING TEST");
}
