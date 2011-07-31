/**
 * String manipulation and comparison utilities.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.util.string;

private import core.stdc.string;

// This should be renamed to uintToString()
char[] intToString( char[] buf, uint val )
{
    assert( buf.length > 9 );
    auto p = buf.ptr + buf.length;

    do
    {
        *--p = cast(char)(val % 10 + '0');
    } while( val /= 10 );

    return buf[p - buf.ptr .. $];
}

char[] intToString( char[] buf, ulong val )
{
    assert( buf.length >= 20 );
    auto p = buf.ptr + buf.length;

    do
    {
        *--p = cast(char)(val % 10 + '0');
    } while( val /= 10 );

    return buf[p - buf.ptr .. $];
}


int dstrcmp( in char[] s1, in char[] s2 )
{
    int  ret = 0;
    auto len = s1.length;
    if( s2.length < len )
        len = s2.length;
    if( 0 != (ret = memcmp( s1.ptr, s2.ptr, len )) )
        return ret;
    return s1.length >  s2.length ? 1 :
           s1.length == s2.length ? 0 : -1;
}
