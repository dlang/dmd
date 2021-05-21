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
