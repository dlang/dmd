module imports.Other; // makes no difference if removed
import Same;
import std.c.stdio;

class Other : Same // segfault
// class Other : Same.Same //***UGLY ALERT*** but doesn't segfault
{
this()
{
printf("other\n");
}
}

int main()
{
    new Other;
    return 0;
}
