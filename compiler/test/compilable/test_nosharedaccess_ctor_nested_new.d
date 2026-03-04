// REQUIRED_ARGS: -preview=nosharedaccess

class Outer
{
    class Inner
    {
    }

    shared this()
    {
        auto i = new shared Inner;
    }
}
