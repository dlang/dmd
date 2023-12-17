/**
 * Implementation of invariant support routines.
 *
 * Copyright: Copyright Digital Mars 2007 - 2010.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Walter Bright
 * Source: $(DRUNTIMESRC rt/_invariant.d)
 */

/*          Copyright Digital Mars 2007 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */

extern (C) void onAssertErrorMsg( string file, size_t line, string msg ) nothrow;

/**
 *
 */
void _d_invariant(Object o)
{   ClassInfo c;

    //printf("__d_invariant(%p)\n", o);


    // check for null object or null vtable (as opposed to just segfaulting)
    // Do this regardless of whether asserts are enabled or not. Since this is
    // in druntime, it likely is compiled without asserts enabled, and clearly
    // the user is OK with extra checks if they are using invariants.
    if (o is null || *cast(void**)o is null)
        // BUG: needs to be filename/line of caller, not library routine
        onAssertErrorMsg(__FILE__, __LINE__, "object is null or has null vtbl");

    c = typeid(o);
    do
    {
        if (c.classInvariant)
        {
            (*c.classInvariant)(o);
        }
        c = c.base;
    } while (c);
}
