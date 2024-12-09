/*
TEST_OUTPUT:
---
fail_compilation/fail10481.d(15): Error: undefined identifier `T1`, did you mean alias `T0`?
void get(T0 = T1.Req, Params...)(Params , T1) {}
     ^
fail_compilation/fail10481.d(19): Error: cannot infer type from template instance `get!(A)`
    auto xxx = get!A;
               ^
---
*/

struct A {}

void get(T0 = T1.Req, Params...)(Params , T1) {}

void main()
{
    auto xxx = get!A;
}
