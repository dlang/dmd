/*
REQUIRED_ARGS: -preview=dip1000
PERMUTE_ARGS:
*/

/*
TEST_OUTPUT:
---
fail_compilation/retscope6.d(6007): Error: copying `& i` into allocated memory escapes a reference to local variable `i`
---
*/

#line 6000

// https://issues.dlang.org/show_bug.cgi?id=17795

int* test() @safe
{
    int i;
    int*[][] arr = new int*[][](1);
    arr[0] ~= &i;
    return arr[0][0];
}

/* TEST_OUTPUT:
---
fail_compilation/retscope6.d(7034): Error: reference to local variable `i` assigned to non-scope parameter `_param_1` calling retscope6.S.emplace!(int*).emplace
fail_compilation/retscope6.d(7035): Error: reference to local variable `i` assigned to non-scope parameter `_param_0` calling retscope6.S.emplace2!(int*).emplace2
fail_compilation/retscope6.d(7024): Error: scope variable `_param_2` assigned to `s` with longer lifetime
fail_compilation/retscope6.d(7025): Error: scope variable `_param_2` assigned to `t` with longer lifetime
fail_compilation/retscope6.d(7037): Error: template instance `retscope6.S.emplace4!(int*)` error instantiating
---
*/

#line 7000

alias T = int*;

struct S
{
    T payload;

    static void emplace(Args...)(ref S s, Args args) @safe
    {
        s.payload = args[0];
    }

    void emplace2(Args...)(Args args) @safe
    {
        payload = args[0];
    }

    static void emplace3(Args...)(S s, Args args) @safe
    {
        s.payload = args[0];
    }

    static void emplace4(Args...)(scope ref S s, scope out S t, scope Args args) @safe
    {
        s.payload = args[0];
        t.payload = args[0];
    }

}

void foo() @safe
{
    S s;
    int i;
    s.emplace(s, &i);
    s.emplace2(&i);
    s.emplace3(s, &i);
    s.emplace4(s, s, &i);
}


/* TEST_OUTPUT:
---
fail_compilation/retscope6.d(8016): Error: reference to local variable `i` assigned to non-scope parameter `s` calling retscope6.frank!().frank
fail_compilation/retscope6.d(8031): Error: reference to local variable `i` assigned to non-scope parameter `p` calling retscope6.betty!().betty
fail_compilation/retscope6.d(8031): Error: reference to local variable `j` assigned to non-scope parameter `q` calling retscope6.betty!().betty
fail_compilation/retscope6.d(8048): Error: reference to local variable `j` assigned to non-scope parameter `q` calling retscope6.archie!().archie
---
*/

// https://issues.dlang.org/show_bug.cgi?id=19035

#line 8000
@safe
{

void escape(int*);

/**********************/

void frank()(ref scope int* p, int* s)
{
    p = s;  // should error here
}

void testfrankly()
{
    int* p;
    int i;
    frank(p, &i);
}

/**********************/

void betty()(int* p, int* q)
{
     p = q;
     escape(p);
}

void testbetty()
{
    int i;
    int j;
    betty(&i, &j); // should error on i and j
}

/**********************/

void archie()(int* p, int* q, int* r)
{
     p = q;
     r = p;
     escape(q);
}

void testarchie()
{
    int i;
    int j;
    int k;
    archie(&i, &j, &k); // should error on j
}

}

/* TEST_OUTPUT:
---
fail_compilation/retscope6.d(9022): Error: returning `fred(& i)` escapes a reference to local variable `i`
---
*/

#line 9000

@safe:

alias T9 = S9!(); struct S9()
{
     this(return int* q)
     {
        this.p = q;
     }

     int* p;
}

auto fred(int* r)
{
    return T9(r);
}

T9 testfred()
{
    int i;
    auto j = fred(&i); // ok
    return fred(&i);   // error
}

