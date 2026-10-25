/*
TEST_OUTPUT:
---
fail_compilation/traits_vtblSymbol.d(21): Error: class type expected as argument to __traits(vtblSymbol) instead of `traits_vtblSymbol.I`
fail_compilation/traits_vtblSymbol.d(22): Error: class or interface type expected as argument to __traits(interfaceSymbol) instead of `S`
fail_compilation/traits_vtblSymbol.d(27): Error: class `traits_vtblSymbol.Grows` must be completely defined before __traits(vtblSymbol)
fail_compilation/traits_vtblSymbol.d(32): Error: class `traits_vtblSymbol.Opaque` must be completely defined before __traits(vtblSymbol)
fail_compilation/traits_vtblSymbol.d(35): Error: cannot dereference pointer to static variable `C` at compile time
fail_compilation/traits_vtblSymbol.d(37):        called from here: `(*(function () pure nothrow @nogc @safe => *__SymbolSlice(6$?:32=u|64=LU$, & C).ptr()))()`
fail_compilation/traits_vtblSymbol.d(37):        while evaluating: `static assert((*(function () pure nothrow @nogc @safe => *__SymbolSlice(6$?:32=u|64=LU$, & C).ptr()))())`
$p:object.d$($n$): Error: slicing pointers to static variables is not supported in CTFE
fail_compilation/traits_vtblSymbol.d(36):        called from here: `__SymbolSlice(6$?:32=u|64=LU$, & C).get()`
fail_compilation/traits_vtblSymbol.d(38):        called from here: `(*(function () pure nothrow @nogc @safe => __SymbolSlice(6$?:32=u|64=LU$, & C).get()[0]))()`
fail_compilation/traits_vtblSymbol.d(38):        while evaluating: `static assert((*(function () pure nothrow @nogc @safe => __SymbolSlice(6$?:32=u|64=LU$, & C).get()[0]))())`
---
*/

interface I {}
struct S {}

enum a = __traits(vtblSymbol, I);
enum b = __traits(interfaceSymbol, S);

class Grows
{
    void f() {}
    static if (__traits(vtblSymbol, Grows).length < 7)
        void g() {}
}

class Opaque;
enum o = __traits(vtblSymbol, Opaque);

class C { void f() {} }
enum d = () => *__traits(vtblSymbol, C).ptr;
enum e = () => __traits(vtblSymbol, C)[0];
static assert(d());
static assert(e());
