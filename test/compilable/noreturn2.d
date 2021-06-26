/*
REQUIRED_ARGS: -w -o-

Type infernce usage mentioned in the DIP:
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

auto loop()
{
    while (true) {}
}

static assert(is(typeof(loop()) == noreturn));

/**************************************************************/

auto throw_()
{
    throw new Exception("");
}

static assert(is(typeof(throw_()) == noreturn));

/**************************************************************/

// Cannot cast int to noreturn...
// auto cast_()
// {
//     return cast(noreturn) 1;
// }

// static assert(is(typeof(throw_()) == noreturn));

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

/**************************************************************
 * Variables
 */
auto checkVariables()
{
    auto nr = assert0();
    static assert(is(typeof(nr) == noreturn));
    return nr;
}

static assert(is(typeof(checkVariables()) == noreturn));

/**************************************************************/

void func()
{
    auto var = assert(0) + assert(0);
}

/**************************************************************
 * Lambdas
 */

static assert(is(typeof({ assert(0); }()) == noreturn));

/**************************************************************/
