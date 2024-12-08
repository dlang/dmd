/*
TEST_OUTPUT:
---
fail_compilation/ice10259.d(21): Error: circular reference to `ice10259.D.d`
    D d = { auto x = new D(); return x; }();
                     ^
fail_compilation/ice10259.d(21):        called from here: `(*function () pure nothrow @safe => x)()`
    D d = { auto x = new D(); return x; }();
                                         ^
fail_compilation/ice10259.d(28): Error: circular reference to `ice10259.D2.d`
    D2 d = function { auto x = new D2(); return x; }();
                               ^
fail_compilation/ice10259.d(28):        called from here: `(*function () pure nothrow @safe => x)()`
    D2 d = function { auto x = new D2(); return x; }();
                                                    ^
---
*/
class D
{
    int x;
    D d = { auto x = new D(); return x; }();
}
enum x = new D;

class D2
{
    int x;
    D2 d = function { auto x = new D2(); return x; }();
}
enum x2 = new D2;
