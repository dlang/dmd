/*
TEST_OUTPUT:
---
fail_compilation/attributediagnostic_nothrow.d(39): Error: function `attributediagnostic_nothrow.layer1` is not `nothrow`
auto layer2() nothrow { layer1(); }
                              ^
fail_compilation/attributediagnostic_nothrow.d(40):        which calls `attributediagnostic_nothrow.layer0`
auto layer1() { layer0(); }
                      ^
fail_compilation/attributediagnostic_nothrow.d(41):        which calls `attributediagnostic_nothrow.gc`
auto layer0() { gc(); }
                  ^
fail_compilation/attributediagnostic_nothrow.d(45):        which wasn't inferred `nothrow` because of:
    asm {}
    ^
fail_compilation/attributediagnostic_nothrow.d(45):        `asm` statement is assumed to throw - mark it with `nothrow` if it does not
fail_compilation/attributediagnostic_nothrow.d(39): Error: function `attributediagnostic_nothrow.layer2` may throw but is marked as `nothrow`
auto layer2() nothrow { layer1(); }
     ^
fail_compilation/attributediagnostic_nothrow.d(61): Error: function `attributediagnostic_nothrow.gc1` is not `nothrow`
    gc1();
       ^
fail_compilation/attributediagnostic_nothrow.d(50):        which wasn't inferred `nothrow` because of:
    throw new Exception("msg");
    ^
fail_compilation/attributediagnostic_nothrow.d(50):        `object.Exception` is thrown but not caught
fail_compilation/attributediagnostic_nothrow.d(62): Error: function `attributediagnostic_nothrow.gc2` is not `nothrow`
    gc2();
       ^
fail_compilation/attributediagnostic_nothrow.d(59): Error: function `D main` may throw but is marked as `nothrow`
void main() nothrow
     ^
---
*/

// Issue 17374 - Improve inferred attribute error message
// https://issues.dlang.org/show_bug.cgi?id=17374

auto layer2() nothrow { layer1(); }
auto layer1() { layer0(); }
auto layer0() { gc(); }

auto gc()
{
    asm {}
}

auto gc1()
{
    throw new Exception("msg");
}

auto fgc = function void() {throw new Exception("msg");};
auto gc2()
{
    fgc();
}

void main() nothrow
{
    gc1();
    gc2();
}
