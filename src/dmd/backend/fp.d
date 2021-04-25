/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/fp.d backend/fp.d)
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/fp.d
 */

 module dmd.backend.fp;

version (SPP) {} else
{
    import core.stdc.math;
    import core.stdc.fenv;
    import dmd.root.longdouble;
    import dmd.backend.cdef;

    extern (C++):

    nothrow:

    int statusFE()
    {
        return 0;
    }

    int testFE()
    {
        return fetestexcept(FE_ALL_EXCEPT);
    }

    void clearFE()
    {
        feclearexcept(FE_ALL_EXCEPT);
    }

    bool have_float_except() { return true; }

    longdouble _modulo(longdouble x, longdouble y)
    {
        version(FreeBSD)
            enum HOST_IS_BSD = true;
        else version(DragonFlyBSD)
            enum HOST_IS_BSD = true;
        else version(OpenBSD)
            enum HOST_IS_BSD = true;
        else
            enum HOST_IS_BSD = false;

        static if (HOST_IS_BSD)
        {
            return fmod(x, y);
        }
        else
        {
            return fmodl(x, y);
        }
    }
}
