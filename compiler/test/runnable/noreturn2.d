/*
PERMUTE_ARGS: -O -inline
RUN_OUTPUT:
---
getAndPrintS
---
*/

import core.stdc.stdio;
import core.exception : AssertError;

/*****************************************/

// noreturn is inferred for functions that always throw
// The code must not strip the destructor when calling a noreturn function

struct WithDtor
{
    __gshared int destroyed;

    int num;

    int acceptNoreturn(int a, int b, int c)
    {
        puts("unreachable");
        return num + a + b + c;
    }

    ~this()
    {
        destroyed += num;
    }
}

noreturn doesThrow()
{
    WithDtor wd = WithDtor(1);
    throw new Exception("");
}

noreturn callDoesThrow()
{
    WithDtor wd = WithDtor(2);
    doesThrow();
}


void testDtors()
{
    try
    {
        callDoesThrow();
        assert(0);
    } catch (Exception e) {}

    assert(WithDtor.destroyed == 3);
}

/*****************************************************************************/

/// Verifies that `func` throws a `Throwable` with `message` at `line`
void testAssertFailure(size_t expLine, string expMsg, void function() func, size_t callLine = __LINE__)
{
    void enforce(bool check, string error)
    {
        if (!check)
            throw new AssertError(error, __FILE__, callLine);
    }

    bool caught;
    try
    {
        func();
    }
    catch (Throwable t)
    {
        // Save members because t might be overwritten by an Assertion failure below
        string actFile = t.file;
        size_t actLine = t.line;
        string actMsg = t.msg;
        caught = true;

        scope (failure)
        {
            printf("\nfile = \"%.*s\"\nline = %zu\nmsg = \"%.*s\"\n\n",
                cast(int) actFile.length, actFile.ptr,
                actLine,
                cast(int) actMsg.length, actMsg.ptr
            );
            fflush(stdout);
        }

        enforce(actFile == __FILE__, "Wrong file");
        enforce(actLine == expLine, "Wrong line");
        enforce(actMsg == expMsg, "Wrong message");
    }

    enforce(caught, "No Throwable was thrown!");
}

void testAccess()
{
    enum msg = "Accessed expression of type `noreturn`";

    testAssertFailure(__LINE__ + 3, msg,
    {
        noreturn a;
        noreturn b = a;
    });

    testAssertFailure(__LINE__ + 3, msg,
    {
        noreturn a;
        int b = a;
    });

    testAssertFailure(__LINE__ + 4, msg,
    {
        noreturn a;
        auto p = &a; // OK
        int b = *p;
    });

    testAssertFailure(__LINE__ + 4, msg,
    {
        noreturn a;
        ref r = a; // OK, reads &a
        int b = r; // asserts
    });

    testAssertFailure(__LINE__ + 2, msg, function noreturn()
    {
        cast(noreturn) 1;
    });

    testAssertFailure(__LINE__ + 3, msg,
    {
        noreturn a;
        noreturn b = cast(noreturn) 1;
    });

    testAssertFailure(__LINE__ + 3, msg, function noreturn()
    {
        noreturn a;
        return a;
    });

    // https://github.com/dlang/dmd/issues/20286
    testAssertFailure(__LINE__ + 4, msg, function noreturn()
    {
        static void foo(noreturn) {}
        noreturn a;
        foo(a);
        assert(false, "Unreachable!"); // Ditto
    });

    // https://github.com/dlang/dmd/issues/22956
    testAssertFailure(__LINE__ + 3, "Assertion failure",
    {
        void function(noreturn) fun;
        fun(assert(0));
    });

    testAssertFailure(__LINE__ + 5, msg,
    {
        static fv(int) {}
        static fr(ref noreturn a)
        {
            fv(a); // asserts
        }
        noreturn a;
        fr(a); // OK, passes &a
    });

    testAssertFailure(__LINE__ + 3, msg,
    {
        noreturn v;
        auto id = typeid(v);
    });

    // test condition
    testAssertFailure(__LINE__ + 3, msg,
    {
        noreturn v;
        if (v)
            return;
    });

    // https://github.com/dlang/dmd/issues/22430
    testAssertFailure(__LINE__ + 3, msg,
    {
        noreturn a;
        auto b = true ? a : 1;
    });

    // https://github.com/dlang/dmd/issues/18186
    {
        noreturn[0] empty = noreturn[0].init;
        noreturn[0] empty2 = empty;
        enum ctfeEmpty = noreturn[0].init;
        static assert(ctfeEmpty.length == 0);
        assert(empty.length == 0 && empty2.length == 0);

        noreturn[0][2] nestedEmpty = noreturn[0][2].init;
        noreturn[0][2] nestedEmpty2 = nestedEmpty;
        enum ctfeNestedEmpty = noreturn[0][2].init;
        static assert(ctfeNestedEmpty.length == 2);
        assert(nestedEmpty.length == 2 && nestedEmpty2.length == 2);
    }

    testAssertFailure(__LINE__ + 2, msg,
    {
        noreturn[1] x = noreturn[1].init;
    });

    testAssertFailure(__LINE__ + 2, msg,
    {
        noreturn[1] x2 = noreturn.init;
    });

    testAssertFailure(__LINE__ + 2, msg,
    {
        noreturn[3] x = noreturn[3].init;
    });

    testAssertFailure(__LINE__ + 2, msg,
    {
        noreturn[1][2] x = noreturn[1][2].init;
    });

    testAssertFailure(__LINE__ + 3, msg,
    {
        noreturn[1] a;
        noreturn[1] b = a;
    });

    testAssertFailure(__LINE__ + 3, msg,
    {
        noreturn[1] x;
        x = noreturn[1].init;
    });

    testAssertFailure(__LINE__ + 3, msg,
    {
        noreturn[1] x;
        x = noreturn.init;
    });

    testAssertFailure(__LINE__ + 3, msg,
    {
        noreturn[2] x;
        x[] = noreturn.init;
    });

    testAssertFailure(__LINE__ + 5, msg,
    {
        static struct S { int a; noreturn n; int b; }
        __gshared int side;
        side = 0;
        S s = S(++side, noreturn.init, ++side);
    });

    // Accessing noreturn variables inside array/struct literals must assert,
    // while custom throws/asserts inside noreturn[N] literals must not be clobbered
    testAssertFailure(__LINE__ + 3, msg,
    {
        noreturn n;
        noreturn[1] y = [n];
    });

    testAssertFailure(__LINE__ + 3, msg,
    {
        noreturn n;
        int[2] y = [1, n];
    });

    testAssertFailure(__LINE__ + 3, msg,
    {
        noreturn[1] na;
        noreturn[1][1] y = [na];
    });

    testAssertFailure(__LINE__ + 4, msg,
    {
        static struct S { int a; noreturn b; }
        noreturn n;
        S s = S(1, n);
    });

    testAssertFailure(__LINE__ + 2, "custom literal",
    {
        noreturn[1] x = [assert(0, "custom literal")];
    });

    testAssertFailure(__LINE__ + 2, "custom casted literal",
    {
        noreturn[1] x = cast(noreturn[1])[assert(0, "custom casted literal")];
    });

    // LHS side effects must still be evaluated before a noreturn RHS
    {
        __gshared int lhsSide;
        static noreturn* getPtr() { ++lhsSide; return null; }

        lhsSide = 0;
        testAssertFailure(__LINE__ + 2, "rhs abort",
        {
            *getPtr() = assert(0, "rhs abort");
        });
        assert(lhsSide == 1);

        static int getIdx() { ++lhsSide; return 0; }
        testAssertFailure(__LINE__ + 3, "rhs abort 2",
        {
            int[2] arr;
            arr[getIdx()] = assert(0, "rhs abort 2");
        });
        assert(lhsSide == 2);
    }
}

/*****************************************/

void testFuncCall()
{
    enum msg = "Called abort()";
    enum line = __LINE__ + 1;
    static noreturn abort() { assert(0, msg); }

    // Canaries to check for side effects
    __gshared int countLeft, countRight;

    scope (failure) printf("countLeft = %d\ncountRight = %d\n", countLeft, countRight);


    // D function arguments are evaluated left to right
    testAssertFailure(line, msg, function()
    {
        static void acceptNoreturnD(int, int, int) { puts("unreachable"); }

        acceptNoreturnD(countLeft++, abort(), countRight++);
    });

    assert(countLeft == 1);
    assert(countRight == 0);

//     // C function arguments are still evaluated left to right
//     // Despite them being push in reverse order
    testAssertFailure(line, msg, function()
    {
        static extern(C) void acceptNoreturnC(int, int, int) { puts("unreachable"); }

        acceptNoreturnC(countLeft++, abort(), countRight++);

        assert(false);
    });

    assert(countLeft == 2);
    assert(countRight == 0);

    WithDtor.destroyed = 0;

    testAssertFailure(__LINE__ + 2, "Error", function()
    {
        static WithDtor getS() { assert(false, "Error"); }

        getS().acceptNoreturn(countLeft++, abort(), countRight++);
    });

    assert(countLeft == 2); // No changes
    assert(countRight == 0);
    assert(WithDtor.destroyed == 0); // No temporary to destruct

    testAssertFailure(line, msg, function()
    {
        static WithDtor getAndPrintS() { puts("getAndPrintS"); return WithDtor(1); }

        getAndPrintS().acceptNoreturn(countLeft++, abort(), countRight++);
    });

    assert(countLeft == 3);
    assert(countRight == 0);
    assert(WithDtor.destroyed == 1);
}

// https://issues.dlang.org/show_bug.cgi?id=24701
void testCast()
{
    noreturn foo;
    try
        auto a = cast(int)foo;
    catch (Throwable e)
    {
        assert(e.msg == "Accessed expression of type `noreturn`");
        return;
    }

    assert(0);
}

// https://github.com/dlang/dmd/issues/20108
int divide(int dividend, int divisor)
{
    return divisor == 0
        ? assert(0, "You shall not divide by zero")
        : dividend / divisor;
}

void testConditional()
{
    assert(divide(1, 2) == 0);
    assert(divide(6, 2) == 3);
}

int main()
{
    testDtors();
    testAccess();
    testFuncCall();
    testCast();
    testConditional();
    return 0;
}
