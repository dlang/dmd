/*
TEST_OUTPUT:
---
fail_compilation/fail18892.d(18): Error: no property `foo` for type `MT`
fail_compilation/fail18892.d(19): Error: no property `foo` for type `MT`
---
*/

struct MT
{
    int _payload;
    alias _payload this;
}

void main()
{
    MT a;
    a.foo = 3;  // Error: no property foo for type MT 
    MT.foo = 3; // Error: no property foo for type int 
}
