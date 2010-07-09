
import std.stdio;

int foo(int i)
{
    int x = void;
    x += 3;
    return i + x;
}

void main()
{
    const y = foo(3);
    writefln(y);
}
