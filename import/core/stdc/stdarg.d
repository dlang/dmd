/**
 * D header file for C99.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 * Standards: ISO/IEC 9899:1999 (E)
 *
 *          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.stdc.stdarg;


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
