struct S
{
    template Temp(int x)
    {
        enum xxx = x;
    }
}

alias TT = __traits(getMember, S, "Temp");
enum x = TT!2.xxx;
static assert(x == 2);
