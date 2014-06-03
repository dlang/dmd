/*
TEST_OUTPUT:
---
fail_compilation/ice10259.d(13): Error: circular reference to 'ice10259.D.d'
fail_compilation/ice10259.d(13):        called from here: (*function () => x)()
fail_compilation/ice10259.d(15): Error: variable ice10259.x : Unable to initialize enum with class or pointer to struct. Use static const variable instead.
---
*/

class D
{
    int x;
    D d = { auto x = new D(); return x; }();
}
enum x = new D;


/*
TEST_OUTPUT:
---
fail_compilation/ice10259.d(30): Error: circular reference to 'ice10259.D2.d'
fail_compilation/ice10259.d(30):        called from here: (*function () => x)()
fail_compilation/ice10259.d(32): Error: variable ice10259.x2 : Unable to initialize enum with class or pointer to struct. Use static const variable instead.
---
*/

class D2
{
    int x;
    D2 d = function { auto x = new D2(); return x; }();
}
enum x2 = new D2;
