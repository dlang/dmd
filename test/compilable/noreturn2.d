/*
REQUIRED_ARGS: -w -o-

Type inference by usage as mentioned in the DIP:
https://github.com/dlang/DIPs/blob/master/DIPs/accepted/DIP1034.md
*/

alias noreturn = typeof(*null);
static assert (!is(noreturn == void));

auto assert0()
{
    assert(0);
}

static assert(is(typeof(assert0()) == noreturn));

/**************************************************************/

auto callAssert0()
{
    assert0();
}

static assert(is(typeof(callAssert0()) == noreturn));

/**************************************************************/

auto maybeCallAssert0(int i)
{
    if (i)
        assert0();
}

static assert(is(typeof(maybeCallAssert0(1)) == void));
static assert(is(typeof(maybeCallAssert0(0)) == void));

/**************************************************************/

auto accessNoreturn()
{
    noreturn nr;
    return nr;
}

static assert(is(typeof(accessNoreturn()) == noreturn));

/**************************************************************/

auto loop()
{
    while (true) {}
}

static assert(is(typeof(loop()) == noreturn));

/**************************************************************/

auto exThrow()
{
    throw new Exception("");
}

static assert(is(typeof(exThrow()) == noreturn));

/**************************************************************/

auto errThrow()
{
    throw new Error("");
}

static assert(is(typeof(errThrow()) == noreturn));

/**************************************************************/

auto thrThrow()
{
    throw new Throwable("");
}

static assert(is(typeof(thrThrow()) == noreturn));

/**************************************************************/

auto cast_()
{
    return cast(noreturn) 1;
}

static assert(is(typeof(cast_()) == noreturn));

/**************************************************************/

auto none()
{
}

static assert(is(typeof(none()) == void));

/**************************************************************/

auto callNone()
{
    none();
}

static assert(is(typeof(callNone()) == void));

/**************************************************************/

auto nestedNoreturn()
{
    auto var = assert(0) + assert(0);
    static assert(is(typeof(var) == noreturn));
}

// FIXME: The DeclarationExp is typed as void and hence not recognized by blockexit
// static assert(is(typeof(nestedNoreturn()) == noreturn));

/**************************************************************
 * Lambdas
 */

static assert(is(typeof({ assert(0); }()) == noreturn));

/**************************************************************
 * DIP example
 */

auto foo(int x) {
    if (x > 0) {
        throw new Exception("");
    } else if (x < 0) {
        while(true) {}
    } else {
        cast(noreturn) /* main */ none();
    }
}

static assert(is(typeof(foo(-1)) == noreturn));
static assert(is(typeof(foo( 0)) == noreturn));
static assert(is(typeof(foo( 1)) == noreturn));
