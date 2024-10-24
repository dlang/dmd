/*
TEST_OUTPUT:
---
fail_compilation/fail222.d(101): Error: template `fail222.getMixin(TArg..., int i = 0)()` template sequence parameter must be the last one
fail_compilation/fail222.d(108): Error: template instance `getMixin!()` does not match template declaration `getMixin(TArg..., int i = 0)()`
fail_compilation/fail222.d(108):        instantiated from here: `getMixin!()`
fail_compilation/fail222.d(101):        Candidate match: getMixin(TArg..., int i = 0)()
fail_compilation/fail222.d(111): Error: template instance `fail222.Thing!()` error instantiating
fail_compilation/fail222.d(113): Error: template `fail222.fooBar(A..., B...)()` template sequence parameter must be the last one
---
*/

#line 100

string getMixin(TArg..., int i = 0)()
{
    return ``;
}

class Thing(TArg...)
{
    mixin(getMixin!(TArg)());
}

public Thing!() stuff;

void fooBar (A..., B...)() {}
