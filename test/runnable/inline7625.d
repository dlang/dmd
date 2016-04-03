// REQUIRED_ARGS:

/***************************************************/
/*
TEST_INLINED:
---
inlined   inline7625.bar1 =>
          inline7625.foo1
inlined   inline7625.bar2 =>
          inline7625.foo2
inlined   inline7625.foo1 =>
          inline7625.test7625a
inlined   inline7625.foo1 =>
          inline7625.test7625a
inlined   inline7625.foo2 =>
          inline7625.test7625a
inlined   inline7625.foo2 =>
          inline7625.test7625a
---
*/

int foo1(int v)
{
    return bar1(2 * v);
}

int bar1(int a)
{
    if (a > 0)
        return 1;
    else
        return baz1(a);
}

int baz1(int a)
{
    if (a > 0)
        throw new Exception("a > 0");
    return a - 1;
}

// ---

int foo2(int v)
{
    return bar2(2 * v);
}

int bar2(int a)
{
    if (a > 0)
        return 1;
    // else
        return baz2(a);
}

int baz2(int a)
{
    if (a > 0)
        throw new Exception("a > 0");
    return a - 1;
}

void test7625a()
{
    assert(foo1(1) ==  1);
    assert(foo1(0) == -1);
    assert(foo2(1) ==  1);
    assert(foo2(0) == -1);
}

/***************************************************/
/*
TEST_INLINED:
---
inlined   inline7625.tembo =>
          inline7625.twiga
inlined   inline7625.pembo =>
          inline7625.simba
inlined   inline7625.twiga =>
          inline7625.test7625b
inlined   inline7625.twiga =>
          inline7625.test7625b
inlined   inline7625.simba =>
          inline7625.test7625b
inlined   inline7625.simba =>
          inline7625.test7625b
---
*/

int tembo(int x, int y)
{
    if (y == 0)
        return 0;
    x++;
    return x / y;
}
int pembo(int x, int y)
{
    if (y == 0)
        return 0;
    else
    {
        x++;
        return x / y;
    }
}

int twiga(int x, int y, int z)
{
    auto w = tembo(x, y);
    return w * z;
}

int simba(int x, int y, int z)
{
    auto w = pembo(x, y);
    return w * z;
}

void test7625b()
{
    assert(twiga(5, 3, 4) == 8);
    assert(twiga(5, 0, 4) == 0);

    assert(simba(5, 3, 4) == 8);
    assert(simba(5, 0, 4) == 0);
}

/***************************************************/
/*
TEST_INLINED:
---
inlined   inline7625.test7625a =>
          D main
inlined   inline7625.test7625b =>
          D main
---
*/

void main()
{
    test7625a();
    test7625b();
}
