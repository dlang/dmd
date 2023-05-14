void f(function ref int() g) { g()++; }

int i;
ref int h() => i;

void main()
{
    f(&h);
    f(ref() => i);
    assert(i == 2);
}

alias Func = function ref int();
static assert(is(Func == typeof(&h)));
