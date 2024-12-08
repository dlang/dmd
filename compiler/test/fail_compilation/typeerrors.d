/*
TEST_OUTPUT:
---
fail_compilation/typeerrors.d(77): Error: sequence index `4` out of bounds `[0 .. 4]`
    T[4] a;
         ^
fail_compilation/typeerrors.d(79): Error: variable `x` cannot be read at compile time
    T[x] b;
         ^
fail_compilation/typeerrors.d(80): Error: cannot have array of `void()`
    typeof(bar)[5] c;
                   ^
fail_compilation/typeerrors.d(81): Error: cannot have array of scope `typeerrors.C`
    C[6] d;
         ^
fail_compilation/typeerrors.d(82): Error: cannot have array of scope `typeerrors.C`
    C[] e;
        ^
fail_compilation/typeerrors.d(85): Error: `int[5]` is not an expression
    auto f = AI.ptr;
             ^
fail_compilation/typeerrors.d(87): Error: variable `x` is used as a type
    int[x*] g;
            ^
fail_compilation/typeerrors.d(78):        variable `x` is declared here
    int x;
        ^
fail_compilation/typeerrors.d(88): Error: cannot have associative array key of `void()`
    int[typeof(bar)] h;
                     ^
fail_compilation/typeerrors.d(89): Error: cannot have associative array key of `void`
    int[void] i;
              ^
fail_compilation/typeerrors.d(90): Error: cannot have array of scope `typeerrors.C`
    C[int] j;
           ^
fail_compilation/typeerrors.d(91): Error: cannot have associative array of `void`
    void[int] k;
              ^
fail_compilation/typeerrors.d(92): Error: cannot have associative array of `void()`
    typeof(bar)[int] l;
                     ^
fail_compilation/typeerrors.d(94): Error: cannot have parameter of type `void`
    void abc(void) { }
         ^
fail_compilation/typeerrors.d(96): Error: slice `[1..5]` is out of range of [0..4]
    alias T2 = T[1 .. 5];
    ^
fail_compilation/typeerrors.d(97): Error: slice `[2..1]` is out of range of [0..4]
    alias T3 = T[2 .. 1];
    ^
fail_compilation/typeerrors.d(99): Error: variable `typeerrors.foo.globalC` globals, statics, fields, manifest constants, ref and out parameters cannot be `scope`
    static C globalC;
             ^
fail_compilation/typeerrors.d(99): Error: variable `typeerrors.foo.globalC` reference to `scope class` must be `scope`
    static C globalC;
             ^
fail_compilation/typeerrors.d(100): Error: variable `typeerrors.foo.manifestC` globals, statics, fields, manifest constants, ref and out parameters cannot be `scope`
    enum C manifestC = new C();
           ^
fail_compilation/typeerrors.d(100): Error: variable `typeerrors.foo.manifestC` reference to `scope class` must be `scope`
    enum C manifestC = new C();
           ^
---
*/


template tuple(T...) { alias T tuple; }

void bar();

scope class C { }

void foo()
{
    alias T = tuple!(1,2,int,7);
    T[4] a;
    int x;
    T[x] b;
    typeof(bar)[5] c;
    C[6] d;
    C[] e;

    alias int[5] AI;
    auto f = AI.ptr;

    int[x*] g;
    int[typeof(bar)] h;
    int[void] i;
    C[int] j;
    void[int] k;
    typeof(bar)[int] l;

    void abc(void) { }

    alias T2 = T[1 .. 5];
    alias T3 = T[2 .. 1];

    static C globalC;
    enum C manifestC = new C();
}
