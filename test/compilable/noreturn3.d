/*
REQUIRED_ARGS: -w -o- -d

More complex examples from the DIP
https://github.com/dlang/DIPs/blob/master/DIPs/accepted/DIP1034.md
*/

alias noreturn = typeof(*null);
static assert (!is(noreturn == void));

void initialize()
{
    noreturn a;
    noreturn b = noreturn.init;
}

void foo(const noreturn);
void foo(const int);

noreturn bar();

void overloads()
{
    noreturn n;
    foo(n);

    foo(bar());
}

// /*****************************************************************************/

auto inferNoreturn(int i)
{
    if (i < 0)
        return assert(false);
    else if (i == 0)
        return assert(false);
    else
        return assert(false);
}

auto inferReturn(int i)
{
    if (i < 0)
        return assert(false);
    else if (i == 0)
        return i;
    else
        return assert(false);
}

// /*****************************************************************************/
// // https://issues.dlang.org/show_bug.cgi?id=22004

alias fun22004 = _ => {}();
alias gun22004 = _ => assert(0);
auto bun22004(bool b)
{
    if (b)
        return gun22004(0);
    else
        return fun22004(0);
}

static assert(is(typeof(bun22004(true)) == void));

// // Reversed order
auto bun22004_reversed(bool b)
{
    if (b)
        return fun22004(0);
    else
        return gun22004(0);
}

static assert(is(typeof(bun22004_reversed(true)) == void));

// /*****************************************************************************/

// // Also works fine with non-void types and ref inference

int global;

auto ref forwardOrExit(ref int num)
{
    if (num)
        return num;
    else
        return assert(false);
}

static assert( is(typeof(forwardOrExit(global)) == int));

// // Must not infer ref due to the noreturn rvalue
static assert(!is(typeof(&forwardOrExit(global))));

auto ref forwardOrExit2(ref int num)
{
    if (num)
        return assert(false);
    else
        return num;
}

static assert( is(typeof(forwardOrExit2(global)) == int));

// // Must not infer ref due to the noreturn rvalue
static assert(!is(typeof(&forwardOrExit2(global))));

/*****************************************************************************/

void inference()
{
    auto inf = cast(noreturn) 1;
    static assert(is(typeof(inf) == noreturn));

    noreturn n;
    auto c = cast(const shared noreturn) n;
    static assert(is(typeof(c) == const shared noreturn));
    static assert(is(typeof(n) == noreturn));

    auto c2 = cast(immutable noreturn) n;
    static assert(is(typeof(c) == const shared noreturn));
    static assert(is(typeof(c2) == immutable noreturn));
    static assert(is(typeof(n) == noreturn));
}
