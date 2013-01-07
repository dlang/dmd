// PERMUTE_ARGS:

// sentinel: should not be picked up
struct std { struct math { @disable static void pow(T...)(T t) { } } }

void t1()
{
    import std.math;
    auto f = (double a, double b) => a ^^ b;
}

void t2()
{
    import std.math;
    {
        auto f = (double a, double b) => a ^^ b;
        {
            auto y = (double a, double b) => a ^^ b;
        }
    }
}
