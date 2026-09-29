// REQUIRED_ARGS: -c
/*
TEST_OUTPUT:
---
true
true
true
---
*/
// https://github.com/dlang/dmd/pull/23940
pragma(msg, __traits(vtblSymbol, Later).length == 6);
enum beforeVtbl = __traits(vtblSymbol, Later).length;
class Later { void foo() {} }
pragma(msg, __traits(vtblSymbol, Later).length == 6);
static assert(beforeVtbl == 6);
static assert(beforeVtbl == __traits(vtblSymbol, Later).length);

struct S { int a = 1; long b = 2; }
pragma(msg, __traits(initSymbol, S).length > 0);
enum initLength = __traits(initSymbol, S).length;
static assert(initLength == S.sizeof);
enum localLength = (() {
    auto x = __traits(initSymbol, S);
    return x.length;
})();
static assert(localLength == S.sizeof);

// Forward references through inheritance, aliases and templates.
enum interfacesBefore = __traits(getInterfaces, Child).length;
interface BaseInterface {}
interface DerivedInterface : BaseInterface {}
class Parent : DerivedInterface {}
class Child : Parent, BaseInterface {}
static assert(interfacesBefore == 1);
static assert(__traits(getInterfaces, DerivedInterface).length == 1);
alias AliasChild = Child;
static assert(__traits(getInterfaces, const(AliasChild)).length == 1);
class TemplateClass(T) { T value; void f() {} }
static assert(__traits(vtblSymbol, TemplateClass!int).length == 6);

enum assigned = (() {
    auto a = __traits(vtblSymbol, Later);
    const(void*)[] b;
    b = a;
    return b;
})();
static assert(assigned.length == 6);
