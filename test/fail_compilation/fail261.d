import std.stdio;

struct MyRange
{
}


void main()
{
    MyRange range;

    foreach (r; range)
    {
        writefln("%s", r.toString());
    }
}
