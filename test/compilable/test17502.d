// https://issues.dlang.org/show_bug.cgi?id=17502
class Foo
{
    auto foo()
    out {}
    body {}

    auto bar()
    out { assert (__result > 5); }
    body { return 6; }

    auto bar_2()
    out (res) { assert (res > 5); }
    body { return 6; }

    int concrete()
    out { assert(__result > 5); }
    body { return 6; }

    int concrete_2()
    out(res) { assert (res > 5); }
    body { return 6; }

    void void_foo()
    out {}
    body {}

    auto void_auto()
    out {}
    body {}
}

/***************************************************/
// Order of declaration: (A), (C : B), (B : A)

class A
{
    int method(int p)
    in
    {
        assert(p > 5);
    }
    out(res)
    {
        assert(res > 5);
    }
    body
    {
        return p;
    }
}

class C : B
{
    override int method(int p)
    in
    {
        assert(p > 3);
    }
    body
    {
        return p * 2;
    }
}

class B : A
{
    override int method(int p)
    in
    {
        assert(p > 2);
    }
    body
    {
        return p * 3;
    }
}

/***************************************************/
// Order of declaration: (X : Y), (Y : Z), (Z)
class X : Y
{
    override int method(int p)
    in
    {
        assert(p > 3);
    }
    body
    {
        return p * 2;
    }
}

class Y : Z
{
    override int method(int p)
    in
    {
        assert(p > 2);
    }
    body
    {
        return p * 3;
    }
}

class Z
{
    int method(int p)
    in
    {
        assert(p > 5);
    }
    out(res)
    {
        assert(res > 5);
    }
    body
    {
        return p;
    }
}
