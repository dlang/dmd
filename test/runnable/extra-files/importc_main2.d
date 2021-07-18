
import std.stdio;
import importc_test;

int main()
{
    intptr_t iptr = cast(intptr_t)(&someCodeInC);
    return 0;
}
