/*
REQUIRED_ARGS: -w -o-

TEST_OUTPUT:
---
fail_compilation/noreturn2.d(59): Error: expected return type of `noreturn`, not `void`
    return doStuff();
    ^
fail_compilation/noreturn2.d(70): Error: expected return type of `int`, not `string`:
        return "";
        ^
fail_compilation/noreturn2.d(68):        Return type of `int` inferred here.
        return i;
        ^
fail_compilation/noreturn2.d(75): Error: function `noreturn2.returns` is typed as `NR` but does return
NR returns()
   ^
fail_compilation/noreturn2.d(75):        `noreturn` functions must either throw, abort or loop indefinitely
fail_compilation/noreturn2.d(82): Error: cannot implicitly convert expression `1` of type `int` to `noreturn`
    return 1;
           ^
fail_compilation/noreturn2.d(87): Error: expected return type of `int`, not `void`
    return doStuff();
    ^
fail_compilation/noreturn2.d(95): Error: mismatched function return type inference of `void` and `int`
        return doStuff();
        ^
fail_compilation/noreturn2.d(102): Error: `object.Exception` is thrown but not caught
            throw
            ^
fail_compilation/noreturn2.d(98): Error: function `noreturn2.doesNestedThrow` may throw but is marked as `nothrow`
int doesNestedThrow(int i) nothrow
    ^
fail_compilation/noreturn2.d(119): Error: cannot create instance of interface `I`
            new
            ^
fail_compilation/noreturn2.d(122): Error: can only throw class objects derived from `Throwable`, not type `int[]`
            throw
            ^
fail_compilation/noreturn2.d(127): Error: undefined identifier `UnkownException`
            new
            ^
fail_compilation/noreturn2.d(134): Error: cannot return from `noreturn` function
    return;
    ^
fail_compilation/noreturn2.d(134):        Consider adding an endless loop, `assert(0)`, or another `noreturn` expression
---

https://issues.dlang.org/show_bug.cgi?id=24054
https://github.com/dlang/DIPs/blob/master/DIPs/accepted/DIP1034.md
*/

alias noreturn = typeof(*null);

void doStuff();

noreturn returnVoid()
{
    return doStuff();
}


auto missmatch(int i)
{
    if (i < 0)
        return assert(false);
    if (i == 0)
        return i;
    if (i > 0)
        return "";
}

enum NR : noreturn;

NR returns()
{
    // Fallthrough despite noreturn
}

noreturn returnsValue()
{
    return 1;
}

int returnVoid2()
{
    return doStuff();
}

auto returnVoid3(int i)
{
    if (i > 0)
        return i;
    else
        return doStuff();
}

int doesNestedThrow(int i) nothrow
{
    // Weird formatting is intended to check the loc
    return i ? i++ :
            throw
            new
            Exception("")
    ;
}

int doesNestedThrowThrowable(int i) nothrow
{
    return i ? i++ : throw new Error("");
}

int throwInvalid(int i) nothrow
{
    static interface I {}
    // Weird formatting is intended to check the loc
    return
            throw
            new
            I()
        ?
            throw
            new
            int[4]
        :
            throw
            new
            UnkownException("")
    ;
}

const(noreturn) f()
{
    return;
}
