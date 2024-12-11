/*
TEST_OUTPUT:
---
fail_compilation/attributediagnostic.d(46): Error: `@safe` function `attributediagnostic.layer2` cannot call `@system` function `attributediagnostic.layer1`
auto layer2() @safe { layer1(); }
                            ^
fail_compilation/attributediagnostic.d(48):        which calls `attributediagnostic.layer0`
auto layer0() { system(); }
     ^
fail_compilation/attributediagnostic.d(50):        which calls `attributediagnostic.system`
auto system()
     ^
fail_compilation/attributediagnostic.d(52):        which wasn't inferred `@safe` because of:
    asm {}
    ^
fail_compilation/attributediagnostic.d(52):        `asm` statement is assumed to be `@system` - mark it with `@trusted` if it is not
fail_compilation/attributediagnostic.d(47):        `attributediagnostic.layer1` is declared here
auto layer1() { layer0(); }
     ^
fail_compilation/attributediagnostic.d(68): Error: `@safe` function `D main` cannot call `@system` function `attributediagnostic.system1`
    system1();
           ^
fail_compilation/attributediagnostic.d(57):        which wasn't inferred `@safe` because of:
    int* x = cast(int*) 0xDEADBEEF;
             ^
fail_compilation/attributediagnostic.d(57):        cast from `uint` to `int*` not allowed in safe code
fail_compilation/attributediagnostic.d(55):        `attributediagnostic.system1` is declared here
auto system1()
     ^
fail_compilation/attributediagnostic.d(69): Error: `@safe` function `D main` cannot call `@system` function `attributediagnostic.system2`
    system2();
           ^
fail_compilation/attributediagnostic.d(63):        which wasn't inferred `@safe` because of:
    fsys();
        ^
fail_compilation/attributediagnostic.d(63):        `@safe` function `system2` cannot call `@system` `fsys`
fail_compilation/attributediagnostic.d(61):        `attributediagnostic.system2` is declared here
auto system2()
     ^
---
*/

// Issue 17374 - Improve inferred attribute error message
// https://issues.dlang.org/show_bug.cgi?id=17374

auto layer2() @safe { layer1(); }
auto layer1() { layer0(); }
auto layer0() { system(); }

auto system()
{
    asm {}
}

auto system1()
{
    int* x = cast(int*) 0xDEADBEEF;
}

auto fsys = function void() @system {};
auto system2()
{
    fsys();
}

void main() @safe
{
    system1();
    system2();
}
