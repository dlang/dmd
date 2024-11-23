/*
TEST_OUTPUT:
---
fail_compilation/fail222.d(19): Error: template `fail222.getMixin(TArg..., int i = 0)()` template sequence parameter must be the last one
string getMixin(TArg..., int i = 0)()
       ^
fail_compilation/fail222.d(26): Error: template instance `getMixin!()` does not match template declaration `getMixin(TArg..., int i = 0)()`
    mixin(getMixin!(TArg)());
          ^
fail_compilation/fail222.d(29): Error: template instance `fail222.Thing!()` error instantiating
public Thing!() stuff;
       ^
fail_compilation/fail222.d(31): Error: template `fail222.fooBar(A..., B...)()` template sequence parameter must be the last one
void fooBar (A..., B...)() {}
     ^
---
*/

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
