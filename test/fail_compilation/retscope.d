/*
REQUIRED_ARGS: -transition=safe
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/retscope.d(23): Error: scope variable p may not be returned
fail_compilation/retscope.d(33): Error: escaping reference to local variable j
fail_compilation/retscope.d(46): Error: scope variable p assigned to non-scope q
fail_compilation/retscope.d(48): Error: cannot take address of local i in @safe function test2
fail_compilation/retscope.d(49): Error: variadic variable a assigned to non-scope b
fail_compilation/retscope.d(50): Error: reference to stack allocated value returned by (*fp2)() assigned to non-scope q
---
*/




int* foo1(return scope int* p) { return p; } // ok

int* foo2()(scope int* p) { return p; }  // ok, 'return' is inferred
alias foo2a = foo2!();

int* foo3(scope int* p) { return p; }   // error

int* foo4(bool b)
{
    int i;
    int j;

    int* nested1(scope int* p) { return null; }
    int* nested2(return scope int* p) { return p; }

    return b ? nested1(&i) : nested2(&j);
}

/************************************************/

struct S2 { int a,b,c,d; }

@safe S2 function() fp2;

void test2(scope int* p, int[] a ...) @safe
{
    static int* q;
    static int[] b;
    q = p;
    int i;
    q = &i;
    b = a;
    q = &fp2().d;
}

/**************************************************/

/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(76): Error: function retscope.HTTP.Impl.onReceive is @nogc yet allocates closures with the GC
fail_compilation/retscope.d(78):        retscope.HTTP.Impl.onReceive.__lambda1 closes over variable this at fail_compilation/retscope.d(76)
---
*/


struct Curl
{
    int delegate() dg;
}

struct HTTP
{
    struct Impl
    {
        Curl curl;
        int x;

        @nogc void onReceive()
        {
            auto dg = ( ) { return x; };
            curl.dg = dg;
        }
    }
}

/***********************************************/

/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(97): Error: reference to local variable sa assigned to non-scope parameter a calling retscope.bar8
---
*/
// https://issues.dlang.org/show_bug.cgi?id=8838

int[] foo8() @safe
{
    int[5] sa;
    return bar8(sa);
}

int[] bar8(int[] a) @safe
{
    return a;
}


/*************************************************/

/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(124): Error: escaping reference to local variable tmp
---
*/

char[] foo9(char[] a) @safe pure nothrow @nogc
{
    return a;
}

char[] bar9() @safe
{
    char[20] tmp;
    foo9(tmp);          // ok
    return foo9(tmp);   // error
}

/*************************************************/

/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(143): To enforce @safe compiler allocates a closure unless the opApply() uses 'scope'
---
*/

struct S10
{
    static int opApply(int delegate(S10*) dg);
}

S10* test10()
{
    foreach (S10* m; S10)
        return m;
    return null;
}

/************************************************/

/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(159): Error: scope variable this may not be returned
---
*/

class C11
{
    @safe C11 foo() scope { return this; }
}


/****************************************************/

/*
TEST_OUTPUT:
---
fail_compilation/retscope.d(178): Error: address of variable i assigned to p with longer lifetime
---
*/



void foo11() @safe
{
    int[] p;
    int[3] i;
    p = i[];
}

