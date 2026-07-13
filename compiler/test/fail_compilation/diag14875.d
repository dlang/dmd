// REQUIRED_ARGS: -o-

deprecated class Dep { }
deprecated immutable int depVar = 10;

/*
TEST_OUTPUT:
---
fail_compilation/diag14875.d(17): Deprecation: class `diag14875.Dep` is deprecated
fail_compilation/diag14875.d(3):        `Dep` is declared here
1: Dep
2: Dep
3: Dep
---
*/

alias X = Foo!Dep;              // deprecation

template Foo(T)
{
    pragma(msg, "1: ", T);      // no message
    enum Foo = cast(void*)Bar!T;
}
template Bar(T)
{
    pragma(msg, "2: ", T);      // no message
    enum Bar = &Baz!T;
}
template Baz(T)
{
    pragma(msg, "3: ", T);      // no message
    immutable Baz = 1234;
}

// ---

/*
TEST_OUTPUT:
---
fail_compilation/diag14875.d(57): Deprecation: class `diag14875.Dep` is deprecated
fail_compilation/diag14875.d(3):        `Dep` is declared here
fail_compilation/diag14875.d(61): Deprecation: variable `diag14875.depVar` is deprecated
fail_compilation/diag14875.d(4):        `depVar` is declared here
fail_compilation/diag14875.d(57):        instantiated from here: `Voo!(Dep)`
4: Dep
fail_compilation/diag14875.d(68): Deprecation: variable `diag14875.depVar` is deprecated
fail_compilation/diag14875.d(4):        `depVar` is declared here
fail_compilation/diag14875.d(64):        instantiated from here: `Var!(Dep)`
fail_compilation/diag14875.d(57):        instantiated from here: `Voo!(Dep)`
fail_compilation/diag14875.d(69): Deprecation: template `diag14875.Vaz(T)` is deprecated
fail_compilation/diag14875.d(71):        `Vaz(T)` is declared here
fail_compilation/diag14875.d(64):        instantiated from here: `Var!(Dep)`
fail_compilation/diag14875.d(57):        instantiated from here: `Voo!(Dep)`
---
*/

alias Y = Voo!Dep;              // deprecation

template Voo(T)
{
    enum n = depVar;            // deprecation
    struct A { alias B = T; }   // no message
    pragma(msg, "4: ", A.B);    // B is not deprecated
    enum Voo = cast(void*)Var!T;
}
template Var(T)
{
    enum n = depVar;            // deprecation
    enum Var = &Vaz!T;          // deprecation
}
deprecated template Vaz(T)
{
    enum n = depVar;            // no message
    immutable Vaz = 1234;
}

/*
TEST_OUTPUT:
---
fail_compilation/diag14875.d(85): Error: static assert:  `0` is false
---
*/
void main()
{
    static assert(0);
}
