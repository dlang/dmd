void f(function ref int() g) { g()++; }

int i;
ref int h() => i;

void main()
{
    f(&h);
    f(ref() => i);
    assert(i == 2);
}
