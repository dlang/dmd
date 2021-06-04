/*
REQUIRED_ARGS: -w -o-

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
