/**
 * The vararg module is intended to facilitate vararg manipulation in D.
 * It should be interface compatible with the C module "stdarg," and the
 * two modules may share a common implementation if possible (as is done
 * here).
 * Copyright: Copyright Digital Mars 2000 - 2009.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Walter Bright, Hauke Duden
 * Source:    $(DRUNTIMESRC core/_vararg.d)
 */

/*          Copyright Digital Mars 2000 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.vararg;

version( X86 )
{
    /**
     * The base vararg list type.
     */
    alias void* va_list;

    /**
     * This function initializes the supplied argument pointer for subsequent
     * use by va_arg and va_end.
     *
     * Params:
     *  ap      = The argument pointer to initialize.
     *  paramn  = The identifier of the rightmost parameter in the function
     *            parameter list.
     */
    void va_start(T)( out va_list ap, ref T parmn )
    {
        ap = cast(va_list)( cast(void*) &parmn + ( ( T.sizeof + int.sizeof - 1 ) & ~( int.sizeof - 1 ) ) );
    }

    /**
     * This function returns the next argument in the sequence referenced by
     * the supplied argument pointer.  The argument pointer will be adjusted
     * to point to the next arggument in the sequence.
     *
     * Params:
     *  ap  = The argument pointer.
     *
     * Returns:
     *  The next argument in the sequence.  The result is undefined if ap
     *  does not point to a valid argument.
     */
    T va_arg(T)( ref va_list ap )
    {
        T arg = *cast(T*) ap;
        ap = cast(va_list)( cast(void*) ap + ( ( T.sizeof + int.sizeof - 1 ) & ~( int.sizeof - 1 ) ) );
        return arg;
    }

    /**
     * This function cleans up any resources allocated by va_start.  It is
     * currently a no-op and exists mostly for syntax compatibility with
     * the variadric argument functions for C.
     *
     * Params:
     *  ap  = The argument pointer.
     */
    void va_end( va_list ap )
    {
    }

    /**
     * This function copied the argument pointer src to dst.
     *
     * Params:
     *  src = The source pointer.
     *  dst = The destination pointer.
     */
    void va_copy( out va_list dst, va_list src )
    {
        dst = src;
    }
}
else
{
    public import core.stdc.stdarg;
}

