// REQUIRED_ARGS: -o-

deprecated class Dep { }
deprecated immutable int depVar = 10;

/*
TEST_OUTPUT:
---
fail_compilation/diag14875.d(49): Deprecation: class `diag14875.Dep` is deprecated
alias X = Foo!Dep;              // deprecation
          ^
1: Dep
2: Dep
3: Dep
fail_compilation/diag14875.d(69): Deprecation: class `diag14875.Dep` is deprecated
alias Y = Voo!Dep;              // deprecation
          ^
fail_compilation/diag14875.d(73): Deprecation: variable `diag14875.depVar` is deprecated
    enum n = depVar;            // deprecation
             ^
fail_compilation/diag14875.d(69):        instantiated from here: `Voo!(Dep)`
alias Y = Voo!Dep;              // deprecation
          ^
4: Dep
fail_compilation/diag14875.d(80): Deprecation: variable `diag14875.depVar` is deprecated
    enum n = depVar;            // deprecation
             ^
fail_compilation/diag14875.d(76):        instantiated from here: `Var!(Dep)`
    enum Voo = cast(void*)Var!T;
                          ^
fail_compilation/diag14875.d(69):        instantiated from here: `Voo!(Dep)`
alias Y = Voo!Dep;              // deprecation
          ^
fail_compilation/diag14875.d(81): Deprecation: template `diag14875.Vaz(T)` is deprecated
    enum Var = &Vaz!T;          // deprecation
                ^
fail_compilation/diag14875.d(76):        instantiated from here: `Var!(Dep)`
    enum Voo = cast(void*)Var!T;
                          ^
fail_compilation/diag14875.d(69):        instantiated from here: `Voo!(Dep)`
alias Y = Voo!Dep;              // deprecation
          ^
fail_compilation/diag14875.d(91): Error: static assert:  `0` is false
    static assert(0);
    ^
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

void main()
{
    static assert(0);
}
