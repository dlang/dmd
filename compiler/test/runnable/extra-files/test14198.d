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
            // [2] its object code would be stored in the library file, because it's instantiated in std14188.uni:
            //     --> FormatSpec!char --> to!string(bool src) in FormatSpec!char.toString()
            //     But semanti3 of FormatSpec!char.toString() won't get called from this module compilation,
            //     so the instantiaion is invisible.
            //     Then, the object code is also stored in test14198.obj, and the link will succeed.
        }
        else
            static assert(0);
        return 0;
    }
}

void main()
{
}
