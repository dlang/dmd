/**
 * Parse command line arguments from response files.
 *
 * This file is not shared with other compilers which use the DMD front-end.
 *
 * Copyright:   Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 *              Some portions copyright (c) 1994-1995 by Symantec
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/response.d, root/_response.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_response.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/response.d
 */

module dmd.root.response;

import dmd.root.file;
import dmd.root.filename;

///
alias responseExpand = responseExpandFrom!lookupInEnvironment;

/*********************************
 * Expand any response files in command line.
 * Response files are arguments that look like:
 *   @NAME
 * The names are resolved by calling the 'lookup' function passed as a template
 * parameter. That function is expected to first check the environment and then
 * the file system.
 * Arguments are separated by spaces, tabs, or newlines. These can be
 * imbedded within arguments by enclosing the argument in "".
 * Backslashes can be used to escape a ".
 * A line comment can be started with #.
 * Recursively expands nested response files.
 *
 * To use, put the arguments in a Strings object and call this on it.
 *
 * Digital Mars's MAKE program can be notified that a program can accept
 * long command lines via environment variables by preceding the rule
 * line for the program with a *.
 *
 * Params:
 *     lookup = alias to a function that is called to look up response file
 *              arguments in the environment. It is expected to accept a null-
 *              terminated string and return a mutable char[] that ends with
 *              a null-terminator or null if the response file could not be
 *              resolved.
 *     args = array containing arguments as null-terminated strings
 *
 * Returns:
 *     `null` on success, or the first response file that could not be found
 */
const(char)* responseExpandFrom(alias lookup)(ref Strings args) nothrow
{
    const(char)* cp;
    bool recurse = false;

    // i is updated by insertArgumentsFromResponse, so no foreach
    for (size_t i = 0; i < args.dim;)
    {
        cp = args[i];
        if (cp[0] != '@')
        {
            ++i;
            continue;
        }
        args.remove(i);
        auto buffer = lookup(&cp[1]);
        if (!buffer)
        {
            /* error         */
            /* BUG: any file buffers are not free'd   */
            return cp;
        }

        recurse = insertArgumentsFromResponse(buffer, args, i) || recurse;
    }
    if (recurse)
    {
        /* Recursively expand @filename   */
        if (auto missingFile = responseExpandFrom!lookup(args))
            /* error         */
            /* BUG: any file buffers are not free'd   */
            return missingFile;
    }
    return null; /* success         */
}

version (unittest)
{
    char[] testEnvironment(const(char)* str) nothrow pure
    {
        import core.stdc.string: strlen;
        import dmd.root.string : toDString;
        switch (str.toDString())
        {
        case "Foo":
            return "foo @Bar #\0".dup;
        case "Bar":
            return "bar @Nil\0".dup;
        case "Error":
            return "@phony\0".dup;
        case "Nil":
            return "\0".dup;
        default:
            return null;
        }
    }
}

unittest
{
    auto args = Strings(4);
    args[0] = "first";
    args[1] = "@Foo";
    args[2] = "@Bar";
    args[3] = "last";

    assert(responseExpand!testEnvironment(args) == null);
    assert(args.length == 5);
    assert(args[0][0 .. 6] == "first\0");
    assert(args[1][0 .. 4] == "foo\0");
    assert(args[2][0 .. 4] == "bar\0");
    assert(args[3][0 .. 4] == "bar\0");
    assert(args[4][0 .. 5] == "last\0");
}

unittest
{
    auto args = Strings(2);
    args[0] = "@phony";
    args[1] = "dummy";
    assert(responseExpand!testEnvironment(args)[0..7] == "@phony\0");
}

unittest
{
    auto args = Strings(2);
    args[0] = "@Foo";
    args[1] = "@Error";
    assert(responseExpand!testEnvironment(args)[0..7] == "@phony\0");
}

/*********************************
 * Take the contents of a response-file 'buffer', parse it and put the resulting
 * arguments in 'args' at 'argIndex'. 'argIndex' will be updated to point just
 * after the inserted arguments.
 * The logic of this should match that in setargv()
 *
 * Params:
 *     buffer = mutable string containing the response file
 *     args = list of arguments
 *     argIndex = position in 'args' where response arguments are inserted
 *
 * Returns:
 *     true if another response argument was found
 */
bool insertArgumentsFromResponse(char[] buffer, ref Strings args, ref size_t argIndex) nothrow pure
{
    bool recurse = false;
    bool comment = false;

    for (size_t p = 0; p < buffer.length; p++)
    {
        //char* d;
        size_t d = 0;
        char c, lastc;
        bool instring;
        int numSlashes, nonSlashes;
        switch (buffer[p])
        {
        case 26:
            /* ^Z marks end of file      */
            return recurse;
        case '\r':
        case '\n':
            comment = false;
            goto case;
        case 0:
        case ' ':
        case '\t':
            continue;
            // scan to start of argument
        case '#':
            comment = true;
            continue;
        case '@':
            if (comment)
            {
                continue;
            }
            recurse = true;
            goto default;
        default:
            /* start of new argument   */
            if (comment)
            {
                continue;
            }
            args.insert(argIndex, &buffer[p]);
            ++argIndex;
            instring = false;
            c = 0;
            numSlashes = 0;
            for (d = p; 1; p++)
            {
                lastc = c;
                if (p >= buffer.length)
                {
                    buffer[d] = '\0';
                    return recurse;
                }
                c = buffer[p];
                switch (c)
                {
                case '"':
                    /*
                    Yes this looks strange,but this is so that we are
                    MS Compatible, tests have shown that:
                    \\\\"foo bar"  gets passed as \\foo bar
                    \\\\foo  gets passed as \\\\foo
                    \\\"foo gets passed as \"foo
                    and \"foo gets passed as "foo in VC!
                    */
                    nonSlashes = numSlashes % 2;
                    numSlashes = numSlashes / 2;
                    for (; numSlashes > 0; numSlashes--)
                    {
                        d--;
                        buffer[d] = '\0';
                    }
                    if (nonSlashes)
                    {
                        buffer[d - 1] = c;
                    }
                    else
                    {
                        instring = !instring;
                    }
                    break;
                case 26:
                    buffer[d] = '\0'; // terminate argument
                    return recurse;
                case '\r':
                    c = lastc;
                    continue;
                    // ignore
                case ' ':
                case '\t':
                    if (!instring)
                    {
                    case '\n':
                    case 0:
                        buffer[d] = '\0'; // terminate argument
                        goto Lnextarg;
                    }
                    goto default;
                default:
                    if (c == '\\')
                        numSlashes++;
                    else
                        numSlashes = 0;
                    buffer[d++] = c;
                    break;
                }
            }
        }
    Lnextarg:
    }
    return recurse;
}

unittest
{
    auto args = Strings(4);
    args[0] = "arg0";
    args[1] = "arg1";
    args[2] = "arg2";

    char[] testData = "".dup;
    size_t index = 1;
    assert(insertArgumentsFromResponse(testData, args, index) == false);
    assert(index == 1);

    testData = (`\\\\"foo bar" \\\\foo \\\"foo \"foo "\"" # @comment`~'\0').dup;
    assert(insertArgumentsFromResponse(testData, args, index) == false);
    assert(index == 6);

    assert(args[1][0 .. 9] == `\\foo bar`);
    assert(args[2][0 .. 7] == `\\\\foo`);
    assert(args[3][0 .. 5] == `\"foo`);
    assert(args[4][0 .. 4] == `"foo`);
    assert(args[5][0 .. 1] == `"`);

    index = 7;
    testData = "\t@recurse # comment\r\ntab\t\"@recurse\"\x1A after end\0".dup;
    assert(insertArgumentsFromResponse(testData, args, index) == true);
    assert(index == 10);
    assert(args[7][0 .. 8] == "@recurse");
    assert(args[8][0 .. 3] == "tab");
    assert(args[9][0 .. 8] == "@recurse");
}

unittest
{
    auto args = Strings(0);

    char[] testData = "\x1A".dup;
    size_t index = 0;
    assert(insertArgumentsFromResponse(testData, args, index) == false);
    assert(index == 0);

    testData = "@\r".dup;
    assert(insertArgumentsFromResponse(testData, args, index) == true);
    assert(index == 1);
    assert(args[0][0 .. 2] == "@\0");

    testData = "ä&#\0".dup;
    assert(insertArgumentsFromResponse(testData, args, index) == false);
    assert(index == 2);
    assert(args[1][0 .. 5] == "ä&#\0");

    testData = "one@\"word \0".dup;
    assert(insertArgumentsFromResponse(testData, args, index) == false);
    args[0] = "one@\"word";
}

/*********************************
 * Try to resolve the null-terminated string cp to a null-terminated char[].
 *
 * The name is first searched for in the environment. If it is not
 * there, it is searched for as a file name.
 *
 * Params:
 *     cp = null-terminated string to look resolve
 *
 * Returns:
 *     a mutable, manually allocated array containing the contents of the environment
 *     variable or file, ending with a null-terminator.
 *     The null-terminator is inside the bounds of the array.
 *     If cp could not be resolved, null is returned.
 */
private char[] lookupInEnvironment(scope const(char)* cp) nothrow {

    import core.stdc.stdlib: getenv;
    import core.stdc.string: strlen;
    import dmd.root.rmem: mem;

    if (auto p = getenv(cp))
    {
        char* buffer = mem.xstrdup(p);
        return buffer[0 .. strlen(buffer) + 1]; // include null-terminator
    }
    else
    {
        auto readResult = File.read(cp);
        if (!readResult.success)
            return null;
        // take ownership of buffer (leaking)
        return cast(char[]) readResult.extractDataZ();
    }
}
