/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/serializer.d, _serializer.d)
 * Documentation:  https://dlang.org/phobos/dmd_serializer.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/serializer.d
 */
module dmd.root.serializer;

import core.internal.traits : Unqual;
import core.stdc.stdarg;

import dmd.root.outbuffer : OutBuffer;
import dmd.root.traits;

/**
 * Serializes the given value to a textual representation.
 *
 * Params:
 *  value = the value to serialize
 *
 * Returns: the serialized data
 */
string serialize(T)(auto ref T value)
{
    OutBuffer buffer;
    Serializer(&buffer).serialize(value);

    return cast(string) buffer.extractSlice;
}

///
struct Serializer
{
    private
    {
        enum Type
        {
            none,
            basic,
        }

        enum indentation = 2;
        int level = 0;
        bool shouldIdent;
        bool isTopLevel = true;
        Type previousType = Type.none;
        OutBuffer* buffer;
    }

    /// Initializes the serializer with the given buffer.
    this(OutBuffer* buffer)
    {
        this.buffer = buffer;
        append("---");
    }

    /**
     * Serializes the given value to a textual representation.
     *
     * This function should be used when customizing the serialization of a type.
     *
     * Params:
     *  value = the value to serialize
     */
    void serialize(T)(ref T value)
    {
        const isTopLevel = this.isTopLevel;
        this.isTopLevel = false;

        static if (isBasicType!T)
            serializeBasicType(value, isTopLevel);
        else
            static assert(false, "Serializing a value of type `" ~ T.stringof ~
                "` is not supported");
    }

private:

    /**
     * Serializes a basic type to a textual representation.
     *
     * Params:
     *  value = the value to serialize
     *  isTopLevel = indicates if this is the first value to be serialized
     */
    void serializeBasicType(T)(T value, bool isTopLevel)
    if (isBasicType!T)
    {
        previousType = Type.basic;

        if (isTopLevel)
            append(' ');

        append(value);
    }

    /**
     * Increases the indentation level for the duration of the given block.
     *
     * Params:
     *  block = the code to execute while the indentation level has been
     *      increased
     */
    void indent(void delegate() block)
    {
        level++;
        scope (exit) level--;
        block();
    }

    /// Writes out the current level of indentation to the buffer.
    void writeIndentation()
    {
        if (shouldIdent)
        {
            foreach (_ ; 0 .. level * indentation)
                buffer.writeByte(' ');
        }
    }

    /// Adds a newline to the buffer.
    void newline()
    {
        buffer.writenl();
        shouldIdent = true;
    }

    /**
     * Appends the given string(s) to the buffer.
     *
     * Params:
     *  strings = the string(s) to append to the buffer
     */
    void append(string[] strings ...)
    {
        writeIndentation();

        foreach (str ; strings)
            buffer.writestring(str);

        shouldIdent = false;
    }

    /**
     * Appends the given value to the buffer.
     *
     * Params:
     *  value = the value to append to the buffer
     */
    void append(T)(T value)
    {
        alias U = Unqual!T;

        static const(char)* printfFormatter(T)()
        {
            static if (is(U == byte) || is(U == ubyte))
                return "%d";
            else static if (is(U == char))
                return "%c";
            else static if (is(U == short) || is (U == int))
                return "%d";
            else static if (is(U == ushort) || is (U == uint))
                return "%u";
            else static if (is(U == long))
                return "%lld";
            else static if (is(U == ulong))
                return "%llu";
            else static if (is(U == float) || is(U == double))
                return "%g";
            else
                static assert(false, "Serializing a value of type `" ~ U.stringof ~ "` is not supported");
        }

        writeIndentation();

        static if (is(U == bool))
            buffer.writestring(value ? "true" : "false");
        else static if (is(U == char) || is(U == wchar) || is(U == dchar))
            buffer.writeUTF8(value);
        else static if (is(U == real))
            buffer.write(value);
        else
            buffer.printf(printfFormatter!U, value);

        shouldIdent = false;
    }
}

private:

/// Evaluates to `true` if `T` is a basic type, otherwise `false`.
template isBasicType(T)
{
    alias U = Unqual!T;

    enum isBasicType =
        !isAggregateType!T &&
        is(U == bool) ||
        is(U == char) ||
        is(U == wchar) ||
        is(U == dchar) ||
        is(U == byte) ||
        is(U == ubyte) ||
        is(U == short) ||
        is(U == ushort) ||
        is(U == int) ||
        is(U == uint) ||
        is(U == long) ||
        is(U == ulong) ||
        is(U == float) ||
        is(U == double) ||
        is(U == real);
}
