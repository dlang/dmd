/*
TEST_OUTPUT:
---
fail_compilation/diag4528.d(24): Error: function `diag4528.Foo.pva` `private` functions cannot be `abstract`
    private abstract void pva();
                          ^
fail_compilation/diag4528.d(25): Error: function `diag4528.Foo.pka` `package` functions cannot be `abstract`
    package abstract void pka();
                          ^
fail_compilation/diag4528.d(26): Error: function `diag4528.Foo.pvsa` `static` functions cannot be `abstract`
    private static abstract void pvsa();
                                 ^
fail_compilation/diag4528.d(27): Error: function `diag4528.Foo.pksa` `static` functions cannot be `abstract`
    package static abstract void pksa();
                                 ^
fail_compilation/diag4528.d(28): Error: function `diag4528.Foo.pbsa` `static` functions cannot be `abstract`
    public static abstract void pbsa();
                                ^
---
*/

class Foo
{
    private abstract void pva();
    package abstract void pka();
    private static abstract void pvsa();
    package static abstract void pksa();
    public static abstract void pbsa();
}
