/*
TEST_OUTPUT:
---
fail_compilation/ice10259.d(12): Error: delegate ice10259.D.__lambda3 function literals cannot be class members
fail_compilation/ice10259.d(15): Error: variable ice10259.x : Unable to initialize enum with class or pointer to struct. Use static const variable instead.
---
*/

class D
{
    int x;
    D d = { auto x = new D(); return x; }();
}

enum x = new D;
