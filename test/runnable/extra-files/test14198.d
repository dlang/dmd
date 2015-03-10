module test14198;

import std14198.conv;

struct S
{
    ptrdiff_t function() fptr = &handler;

    static ptrdiff_t handler() pure @safe
    {
        static if (is(typeof(to!string(false))))
        {
            to!string(false);
            // [1] to!string(bool src) should be deduced to pure @safe, and the function will be mangled to:
            //     --> _D8std141984conv11__T2toTAyaZ9__T2toTbZ2toFNaNbNiNfbZAya
            // [2] its object code should be stored in the library file, because it's instantiated in std14188.uni:
            //     --> FormatSpec!char --> to!string(bool src) in FormatSpec!char.toString()
        }
        else
            static assert(0);
        return 0;
    }
}

void main()
{
}
