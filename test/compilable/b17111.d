import std.stdio : readf, writeln;
alias TestType = ubyte;

void main()
{
    TestType a,b,c;
    readf("%s %s %s ", &a, &b, &c);

    switch(c)
    {
        case a              : writeln("a") ;break;
        case (cast(ushort)b): writeln("b") ;break;
        default             : assert(false);
    }
}
