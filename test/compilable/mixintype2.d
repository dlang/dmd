
alias fun = mixin("(){}");

void test1()
{
    int x = 1;
    static immutable c = 2;

    fun();
    foo!(mixin("int"))();
    foo!(mixin("long*"))();
    foo!(mixin("ST!(int, S.T)"))();
    foo!(mixin(ST!(int, S.T)))();

    int[mixin("string")] a1;
    int[mixin("5")] a2;
    int[mixin("c")] a3;
    int[] v1 = new int[mixin("3")];
    auto v2 = new int[mixin("x")];

    mixin(q{__traits(getMember, S, "T")}) ftv;

    alias T = int*;
    static assert(__traits(compiles, mixin("int")));
    static assert(__traits(compiles, mixin(q{int[mixin("string")]})));
    static assert(__traits(compiles, mixin(q{int[mixin("2")]})));
    static assert(__traits(compiles, mixin(T)));
    static assert(__traits(compiles, mixin("int*")));
    static assert(__traits(compiles, mixin(typeof(0))));
}

struct S { alias T = float*; }

struct ST(X,Y) {}

void foo(alias t)() {}
