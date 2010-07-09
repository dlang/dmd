
import std.stdio;

int foo(int i)
{
    int x = void;
    x++;
    return i + x;
}

void main()
{
    const y = foo(3);
    writefln(y);
}
