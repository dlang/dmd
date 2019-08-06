/* REQUIRED_ARGS: -preview=nosharedaccess
 * TEST_OUTPUT:
---
fail_compilation/nosharedaccess.d(1010): Error: direct access to shared `j` is not allowed, see `core.atomic`
fail_compilation/nosharedaccess.d(1011): Error: direct access to shared `j` is not allowed, see `core.atomic`
fail_compilation/nosharedaccess.d(1012): Error: direct access to shared `*p` is not allowed, see `core.atomic`
fail_compilation/nosharedaccess.d(1013): Error: direct access to shared `a[0]` is not allowed, see `core.atomic`
fail_compilation/nosharedaccess.d(1014): Error: direct access to shared `s.si` is not allowed, see `core.atomic`
fail_compilation/nosharedaccess.d(1015): Error: direct access to shared `t` is not allowed, see `core.atomic`
fail_compilation/nosharedaccess.d(1015): Error: direct access to shared `t.i` is not allowed, see `core.atomic`
---
*/

#line 1000

struct S
{
    shared(int) si;
    int i;
}

int test1(shared int j, shared(int)* p, shared(int)[] a, ref S s, ref shared S t)
{
    int i;
    j = i;
    i = j;
    i = *p;
    i = a[0];
    i = s.si;
    return t.i;
}

/**************************************/

void byref(ref shared int);
void byptr(shared(int)*);

shared int x;

void test2()
{
    byref(x);   // ok
    byptr(&x);  // ok
}

/**************************************/

/*
 * TEST_OUTPUT:
---
fail_compilation/nosharedaccess.d(2008): Error: direct access to shared `i` is not allowed, see `core.atomic`
fail_compilation/nosharedaccess.d(2009): Error: direct access to shared `j` is not allowed, see `core.atomic`
fail_compilation/nosharedaccess.d(2010): Error: direct access to shared `k` is not allowed, see `core.atomic`
---
 */

#line 2000

void func(int);

shared int i;

void test3(shared int k)
{
    shared int j = void;
    func(i);
    func(j);
    func(k);
}

