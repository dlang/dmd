/**
 * Functions for modifying environment variables.
 *
 * Copyright:   Copyright (C) 1999-2022 by The D Language Foundation, All Rights Reserved
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/env.d, env.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_env.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/env.d
 */

module dmd.root.env;

import core.stdc.string;
import core.sys.posix.stdlib;
import dmd.root.array;
import dmd.root.rmem;
import dmd.root.string;

version (Windows)
    private extern (C) int putenv(const char*) nothrow;

nothrow:

/**
Construct a variable from `name` and `value` and put it in the environment while saving
the previous value of the environment variable into a global list so it can be restored later.
Params:
    name = the name of the variable
    value = the value of the variable
Returns:
    true on error, false on success
*/
bool putenvRestorable(const(char)[] name, const(char)[] value) nothrow
{
    saveEnvVar(name);
    const nameValue = allocNameValue(name, value);
    const result = putenv(cast(char*)nameValue.ptr);
    version (Windows)
        mem.xfree(cast(void*)nameValue.ptr);
    else
    {
        if (result)
            mem.xfree(cast(void*)nameValue.ptr);
    }
    return result ? true : false;
}

/**
Allocate a new variable via xmalloc that can be added to the global environment. The
resulting string will be null-terminated immediately after the end of the array.
Params:
    name = name of the variable
    value = value of the variable
Returns:
    a newly allocated variable that can be added to the global environment
*/
string allocNameValue(const(char)[] name, const(char)[] value) nothrow
{
    const length = name.length + 1 + value.length;
    auto str = (cast(char*)mem.xmalloc(length + 1))[0 .. length];
    str[0 .. name.length] = name[];
    str[name.length] = '=';
    str[name.length + 1 .. length] = value[];
    str.ptr[length] = '\0';
    return cast(string)str;
}

/// Holds the original values of environment variables when they are overwritten.
private __gshared string[string] envNameValues;

/// Restore the original environment.
void restoreEnvVars() nothrow
{
    foreach (var; envNameValues.values)
    {
        if (putenv(cast(char*)var.ptr))
            assert(0);
    }
}

/// Save the environment variable `name` if not saved already.
void saveEnvVar(const(char)[] name) nothrow
{
    if (!(name in envNameValues))
    {
        envNameValues[name.idup] = allocNameValue(name, name.toCStringThen!(n => getenv(n.ptr)).toDString);
    }
}
