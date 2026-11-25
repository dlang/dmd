/*
REQUIRED_ARGS: -betterC
PERMUTE_ARGS: -O -inline -release -g
*/

// https://github.com/dlang/dmd/issues/18186

struct S
{
    int x;
    noreturn n;
}

extern(C) void test18186()
{
    noreturn[0] e = noreturn[0].init;
    noreturn[1] x = noreturn[1].init;
    noreturn[1] x2 = noreturn.init;
    noreturn[1][2] x3 = noreturn[1][2].init;
    S s = S(1, noreturn.init);
}
