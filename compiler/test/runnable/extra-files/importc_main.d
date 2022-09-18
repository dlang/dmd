
import std.stdio;
import importc_test;

int main()
{
    auto rc = someCodeInC(3, 4);
    writeln("Result of someCodeInC(3,4) = ", rc );
    assert( rc == 7, "Wrong result");
    return 0;
}
