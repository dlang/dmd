interface ITest
{
    int foo();

    final void bar(int k)() { assert(foo() == k); }
}

class Test : ITest
{
    override int foo() { return 12; }
}

shared static this()
{
    auto test = new Test;
    test.bar!12();
}
