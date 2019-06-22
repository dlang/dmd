/**
 * Pure wrapper of `errno`.
 *
 * Compiler implementation of the D programming language
 * http://dlang.org
 *
 * Copyright: Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:   Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/errno.d, root/_errno.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_errno.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/errno.d
 */
module dmd.root.errno;

static import core.stdc.errno;

/**
 * Restores `errno` after calling `func`.
 *
 * Params:
 *  func = the action to perform before `errno` is restored
 *
 * Returns: whatever `func` returns
 */
package auto restoreErrno(alias func)()
{
    const savedErrno = fakePureErrno;

    static if (is(typeof(func) T == return))
        alias ReturnType = T;

    static if (is(ReturnType == void))
        func();
    else
        auto result = func();

    fakePureErrno = savedErrno;

    static if (!is(ReturnType == void))
        return result;
}

///
unittest
{
    import core.stdc.errno : errno;

    assert(errno == 0);
    auto result = restoreErrno!(() => errno = 3);
    assert(errno == 0);
    assert(result == 3);
}

private:

static if (__traits(getOverloads, core.stdc.errno, "errno").length == 1
    && __traits(getLinkage, core.stdc.errno.errno) == "C")
{
    extern(C) pragma(mangle, __traits(identifier, core.stdc.errno.errno))
    ref int fakePureErrno() pure nothrow @nogc @system;
}
else
{
    extern(C) pure nothrow @nogc @system @property
    {
        pragma(mangle, "getErrno")
        int fakePureErrno();

        pragma(mangle, "setErrno")
        int fakePureErrno(int);
    }
}
