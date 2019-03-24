/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/array.d, root/_array.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_array.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/array.d
 */
module dmd.root.string;

/**
 * Converts the given string to a null terminated C string and passes it to the
 * given callable `func`.
 *
 * The string is only valid during the call to `func` and will be freed after
 * `func` returns.
 *
 * Params:
 *  func = something callable to call
 *  str = the D string to convert
 *
 * Returns: the return value of `func`
 */
auto toStringzThen(alias func)(const(char)[] str)
{
    import dmd.root.rmem : pureMalloc, pureFree;

    if (str.length == 0)
        return func(&""[0]);

    char[1024] staticBuffer;
    const newLength = str.length + 1;
    char[] buffer;

    if (str.length >= buffer.length)
        buffer = (cast(char*) pureMalloc(newLength * char.sizeof))[0 .. newLength];
    else
        buffer = staticBuffer[0 .. newLength];

    scope (exit)
    {
        if (&buffer[0] != &staticBuffer[0])
            pureFree(&buffer[0]);
    }

    buffer[0 .. $ - 1] = str;
    buffer[$ - 1] = '\0';

    return func(&buffer[0]);
}

pure nothrow @nogc unittest
{
    import core.stdc.string : strcmp;

    enum value = "foo";
    value.toStringzThen!(str => assert(str.strcmp(value) == 0));
}
