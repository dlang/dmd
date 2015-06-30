/**
 * String manipulation and comparison utilities.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sean Kelly, Walter Bright
 * Source: $(DRUNTIMESRC src/rt/util/_string.d)
 */

module core.internal.string;

pure:
nothrow:
@nogc:

alias UnsignedStringBuf = char[20];

char[] unsignedToTempString(ulong value, char[] buf, uint radix) @safe
{
    size_t i = buf.length;
    do
    {
        ubyte x = cast(ubyte)(value % radix);
        value = value / radix;
        buf[--i] = cast(char)((x < 10) ? x + '0' : x - 10 + 'a');
    } while (value);
    return buf[i .. $];
}

unittest
{
    UnsignedStringBuf buf;
    assert(0.unsignedToTempString(buf, 10) == "0");
    assert(1.unsignedToTempString(buf, 10) == "1");
    assert(12.unsignedToTempString(buf, 10) == "12");
    assert(0x12ABCF .unsignedToTempString(buf, 16) == "12abcf");
    assert(long.sizeof.unsignedToTempString(buf, 10) == "8");
    assert(uint.max.unsignedToTempString(buf, 10) == "4294967295");
    assert(ulong.max.unsignedToTempString(buf, 10) == "18446744073709551615");
}


int dstrcmp( in char[] s1, in char[] s2 ) @trusted
{
    import core.stdc.string : memcmp;

    int  ret = 0;
    auto len = s1.length;
    if( s2.length < len )
        len = s2.length;
    if( 0 != (ret = memcmp( s1.ptr, s2.ptr, len )) )
        return ret;
    return s1.length >  s2.length ? 1 :
           s1.length == s2.length ? 0 : -1;
}


