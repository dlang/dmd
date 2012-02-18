module test313b;

import imports.test313b;

void foo()
{
    imports.test313priv.foo();
    static assert(0, "FAILING TEST");
}
