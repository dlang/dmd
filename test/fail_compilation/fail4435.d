
interface A
{
    final void fun() {}
}

interface B
{
    final void fun() {}
}

class C : A, B
{
}

void main()
{
    auto c = new C();
    c.fun();
}
