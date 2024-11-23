// EXTRA_SOURCES: imports/b18219.d
// EXTRA_FILES: imports/a18219.d
/*
TEST_OUTPUT:
---
fail_compilation/fail18219.d(27): Error: no property `Foobar` for type `AST`, did you mean `b18219.Foobar`?
    AST.Foobar t;
               ^
fail_compilation/fail18219.d(28): Error: no property `Bar` for type `a18219.AST`
    AST.Bar l;
            ^
fail_compilation/imports/a18219.d(3):        struct `AST` defined here
struct AST
^
fail_compilation/fail18219.d(29): Error: no property `fun` for type `AST`, did you mean `b18219.fun`?
    AST.fun();
    ^
fail_compilation/fail18219.d(30): Error: no property `Foobar` for type `AST`, did you mean `b18219.Foobar`?
    AST.Foobar.smeth();
    ^
---
*/
import imports.a18219;

void main()
{
    AST.Foobar t;
    AST.Bar l;
    AST.fun();
    AST.Foobar.smeth();
}
