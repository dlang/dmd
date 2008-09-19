/**
 * D header file for C99.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Hauke Duden, Walter Bright
 * Standards: ISO/IEC 9899:1999 (E)
 */
module stdc.stdarg;


version( GNU )
{
    public import std.c.stdarg;
}
else
{
    alias void* va_list;

    template va_start( T )
    {
        void va_start( out va_list ap, inout T parmn )
        {
            ap = cast(va_list) ( cast(void*) &parmn + ( ( T.sizeof + int.sizeof - 1 ) & ~( int.sizeof - 1 ) ) );
        }
    }

    template va_arg( T )
    {
        T va_arg( inout va_list ap )
        {
            T arg = *cast(T*) ap;
            ap = cast(va_list) ( cast(void*) ap + ( ( T.sizeof + int.sizeof - 1 ) & ~( int.sizeof - 1 ) ) );
            return arg;
        }
    }

    void va_end( va_list ap )
    {

    }

    void va_copy( out va_list dest, va_list src )
    {
        dest = src;
    }
}
