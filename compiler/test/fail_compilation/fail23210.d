/*
TEST_OUTPUT:
---
fail_compilation/fail23210.d(44): Error: variable `fail23210.main.b` - default construction is disabled for type `B`
fail_compilation/fail23210.d(39):        because field `a` of type `A` has disabled default construction
fail_compilation/fail23210.d(28):        because field `c` of type `C` has disabled default construction
fail_compilation/fail23210.d(17):        because of `@disable this();` here
---
*/

// https://github.com/dlang/dmd/issues/23210

struct C
{
    int x;

    @disable this();

    this(int x)
    {
        this.x = x;
    }
}

struct A
{
    int n;
    C c;

    this(int n)
    {
        this.n = n;
        this.c = C(n);
    }
}

struct B
{
    A a;
}

void main()
{
    B b;
}
