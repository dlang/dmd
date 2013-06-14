// PERMUTE_ARGS:

import std.math;

void t1()
{
    // sentinel: should not be picked up
    struct std { struct math { @disable static void pow(T...)(T t) { } } }
    auto f = (double a, double b) => a ^^ b;
}

void t2()
{
    // sentinel: should not be picked up
    struct std { struct math { @disable static void pow(T...)(T t) { } } }
    {
        auto f = (double a, double b) => a ^^ b;
        {
            auto y = (double a, double b) => a ^^ b;
        }
    }
}
