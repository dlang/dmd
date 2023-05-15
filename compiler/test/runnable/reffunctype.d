// REQUIRED_ARGS: -unittest -main

void f(function ref int() g) { g()++; }

int i;
ref int h() => i;

unittest
{
    f(&h);
    f(ref() => i);
    assert(i == 2);
    
    function ref int() fp = &h;
    fp()++;
    assert(i == 3);
}

alias Func = function ref int();
static assert(is(Func == typeof(&h)));

struct S
{
    int i;
    ref int get() => i;
}

unittest
{
    S s;
    delegate ref int() d = &s.get;
    d()++;
    assert(s.i == 1);
}

alias Del = delegate ref int();
static assert(is(Del == typeof(&S().get)));
