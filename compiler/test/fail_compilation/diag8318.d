/*
TEST_OUTPUT:
---
fail_compilation/diag8318.d(30): Error: function `diag8318.Bar8318.foo` return type inference is not supported if may override base class function
    override auto foo() { return "Bar.foo"; }
                  ^
fail_compilation/diag8318.d(35): Error: function `diag8318.C10021.makeI` return type inference is not supported if may override base class function
class C10021 : I10021 { auto   makeI() { return this; } }
                               ^
fail_compilation/diag8318.d(43): Error: function `diag8318.Bar10195.baz` return type inference is not supported if may override base class function
    override auto baz() { return 1; }
                  ^
fail_compilation/diag8318.d(49): Error: function `diag8318.B14173.foo` does not override any function
    override foo() {}
             ^
fail_compilation/diag8318.d(35): Error: class `diag8318.C10021` interface function `I10021 makeI()` is not implemented
class C10021 : I10021 { auto   makeI() { return this; } }
^
fail_compilation/diag8318.d(41): Error: class `diag8318.Bar10195` interface function `int baz()` is not implemented
class Bar10195 : Foo10195
^
---
*/
class Foo8318
{
    auto foo() { return "Foo.foo"; }
}
class Bar8318 : Foo8318
{
    override auto foo() { return "Bar.foo"; }
}

interface I10021 { I10021 makeI(); }
class D10021 : I10021 { D10021 makeI() { return this; } }
class C10021 : I10021 { auto   makeI() { return this; } }

interface Foo10195
{
    int baz();
}
class Bar10195 : Foo10195
{
    override auto baz() { return 1; }
}

class A14173 {}
class B14173 : A14173
{
    override foo() {}
}
