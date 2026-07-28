module stats;

// Percent change from `base` to `head`.
double deltaPct(double base, double head)
{
    if (base == 0)
        return 0;
    return (head - base) / base * 100.0;
}

unittest
{
    import std.math : isClose;
    assert(isClose(deltaPct(100, 101), 1.0));
    assert(isClose(deltaPct(200, 150), -25.0));
    assert(deltaPct(0, 5) == 0);
}
