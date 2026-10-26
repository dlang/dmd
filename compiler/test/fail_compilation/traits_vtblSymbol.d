/*
TEST_OUTPUT:
---
fail_compilation/traits_vtblSymbol.d(17): Error: class type expected as argument to __traits(vtblSymbol) instead of `traits_vtblSymbol.I`
fail_compilation/traits_vtblSymbol.d(18): Error: class type expected as argument to __traits(vtblSymbol) instead of `int`
fail_compilation/traits_vtblSymbol.d(19): Error: class or interface type expected as argument to __traits(interfaceSymbol) instead of `S`
fail_compilation/traits_vtblSymbol.d(24): Error: the vtable of class `traits_vtblSymbol.Derived` cannot be determined before its base classes are complete
fail_compilation/traits_vtblSymbol.d(33): Error: cannot declare virtual function `g` because the vtable of `Grows` is already sealed
fail_compilation/traits_vtblSymbol.d(40): Error: circular reference to the vtable of class `traits_vtblSymbol.Circular`
fail_compilation/traits_vtblSymbol.d-mixin-40(40): Error: cannot declare virtual function `g` because the vtable of `Circular` is already sealed
---
*/

interface I {}
struct S {}

enum a = __traits(vtblSymbol, I);
enum b = __traits(vtblSymbol, int);
enum c = __traits(interfaceSymbol, S);

// a base class asking about a class derived from it
class Base
{
    enum n = __traits(vtblSymbol, Derived).length;
}
class Derived : Base {}

// the vtable is determined before `g` is declared
class Grows
{
    void f() {}
    static if (__traits(vtblSymbol, Grows).length < 7)
        void g() {}
}

// its own declarations depend on the vtable
class Circular
{
    void f() {}
    mixin(__traits(vtblSymbol, Circular).length > 6 ? "" : "void g() {}");
}
