/*
REQUIRED_ARGS: -unittest -main -de
TEST_OUTPUT:
---
fail_compilation/loopclosures.d(39): Deprecation: Using variable `i` declared in a loop from a closure is deprecated
fail_compilation/loopclosures.d(41):        Variable `i` used in possibly escaping function `f`
fail_compilation/loopclosures.d(58): Deprecation: Using variable `j` declared in a loop from a closure is deprecated
fail_compilation/loopclosures.d(59):        Variable `j` used in possibly escaping function `f`
fail_compilation/loopclosures.d(74): Deprecation: Using variable `i` declared in a loop from a closure is deprecated
fail_compilation/loopclosures.d(76):        Variable `i` used in possibly escaping function `f`
fail_compilation/loopclosures.d(95): Deprecation: Using variable `i` declared in a loop from a closure is deprecated
fail_compilation/loopclosures.d(97):        Variable `i` used in possibly escaping function `__lambda_L97_C15`
fail_compilation/loopclosures.d(116): Deprecation: Using variable `i` declared in a loop from a closure is deprecated
fail_compilation/loopclosures.d(118):        Variable `i` used in possibly escaping function `__lambda_L118_C15`
fail_compilation/loopclosures.d(137): Deprecation: Using variable `i` declared in a loop from a closure is deprecated
fail_compilation/loopclosures.d(139):        Variable `i` used in possibly escaping function `__lambda_L139_C16`
fail_compilation/loopclosures.d(152): Deprecation: Using variable `i` declared in a loop from a closure is deprecated
fail_compilation/loopclosures.d(155):        Variable `i` used in possibly escaping function `__lambda_L155_C13`
fail_compilation/loopclosures.d(169): Deprecation: Using variable `i` declared in a loop from a closure is deprecated
fail_compilation/loopclosures.d(173):        Variable `i` used in possibly escaping function `f`
fail_compilation/loopclosures.d(190): Deprecation: Using variable `i` declared in a loop from a closure is deprecated
fail_compilation/loopclosures.d(194):        Variable `i` used in possibly escaping function `f`
fail_compilation/loopclosures.d(217): Deprecation: Using variable `i` declared in a loop from a closure is deprecated
fail_compilation/loopclosures.d(219):        Variable `i` used in possibly escaping function `__lambda_L219_C21`
fail_compilation/loopclosures.d(246): Deprecation: Using variable `i` declared in a loop from a closure is deprecated
fail_compilation/loopclosures.d(248):        Variable `i` used in possibly escaping function `__lambda_L248_C27`
fail_compilation/loopclosures.d(264): Deprecation: Using variable `i` declared in a loop from a closure is deprecated
fail_compilation/loopclosures.d(268):        Variable `i` used in possibly escaping function `run`
---
*/

void delegate()[] funcsGlobal;
int[] resultsGlobal;

unittest
{
    void delegate()[] funcs;
    int[] results;
    foreach (i; 0..3)
    {
        void f()
        {
            results ~= i;
        }
        funcs ~= &f;
    }
    foreach (dg; funcs)
        dg();
    assert(results == [0, 1, 2]);
}

unittest
{
    void delegate()[] funcs;
    int[] results;
    for (int i = 0; i < 3; i++)
    {
        const j = i;
        void f()
        {
            results ~= j;
        }
        funcs ~= &f;
    }
    foreach (dg; funcs)
        dg();
    assert(results == [0, 1, 2]);
}

unittest
{
    funcsGlobal = [];
    resultsGlobal = [];
    foreach (i; 0..3)
    {
        void f()
        {
            resultsGlobal ~= i;
        }
        funcsGlobal ~= &f;
    }
    foreach (dg; funcsGlobal)
        dg();
    assert(resultsGlobal == [0, 1, 2]);
}

unittest
{
    void delegate()[] funcs;
    int[] results;
    void addDg(void delegate() dg)
    {
        funcs ~= dg;
    }
    foreach (i; 0..3)
    {
        addDg(() {
            results ~= i;
        });
    }
    foreach (dg; funcs)
        dg();
    assert(results == [0, 1, 2]);
}

unittest
{
    void delegate()[] funcs;
    int[] results;
    void addDg(int delegate() dg)
    {
        funcs ~= () {
            results ~= dg();
        };
    }
    foreach (i; 0..3)
    {
        addDg(() {
            return i;
        });
    }
    foreach (dg; funcs)
        dg();
    assert(results == [0, 1, 2]);
}

unittest
{
    void delegate()[] funcs;
    int[] results;
    void addDg(alias F)()
    {
        funcs ~= () {
            results ~= F();
        };
    }
    foreach (i; 0..3)
    {
        addDg!(() {
            return i;
        })();
    }
    foreach (dg; funcs)
        dg();
    assert(results == [0, 1, 2]);
}

unittest
{
    void delegate()[] funcs;
    int[] results;
    foreach (i; 0..3)
    {
        funcs ~= () {
            () {
                results ~= i;
            }();
        };
    }
    foreach (dg; funcs)
        dg();
    assert(results == [0, 1, 2]);
}

unittest
{
    void delegate()[] funcs;
    int[] results;
    foreach (i; 0..3)
    {
        struct S
        {
            void f()
            {
                results ~= i;
            }
        }
        S s;
        funcs ~= &s.f;
    }
    foreach (dg; funcs)
        dg();
    assert(results == [0, 1, 2]);
}

unittest
{
    void delegate()[] funcs;
    int[] results;
    foreach (i; 0..3)
    {
        class C
        {
            void f()
            {
                results ~= i;
            }
        }
        C c = new C;
        funcs ~= &c.f;
    }
    foreach (dg; funcs)
        dg();
    assert(results == [0, 1, 2]);
}

void addDgAlias(alias F)()
{
    funcsGlobal ~= () {
        resultsGlobal ~= F();
    };
}
unittest
{
    funcsGlobal = [];
    resultsGlobal = [];
    foreach (i; 0..3)
    {
        addDgAlias!(() {
            return i;
        })();
    }
    foreach (dg; funcsGlobal)
        dg();
    assert(resultsGlobal == [0, 1, 2]);
}

void callRun(T)(T x)
{
    x.run();
}
auto createS(alias F)()
{
    struct S(alias F)
    {
        void run()
        {
            F();
        }
    }
    return S!F();
}
unittest
{
    int[] results;
    foreach (i; 0..3)
    {
        auto s = createS!((){
            results ~= i;
        })();
        callRun(s);
    }
    assert(results == [0, 1, 2]);
}

abstract class Base
{
    abstract void run();
}
unittest
{
    Base[] instances;
    int[] results;
    foreach (i; 0..3)
    {
        class C : Base
        {
            override void run()
            {
                results ~= i;
            }
        }
        instances ~= new C;
    }
    foreach (instance; instances)
        instance.run();
    assert(results == [0, 1, 2]);
}
