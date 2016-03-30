/**
 * Compiler implementation of the D programming language
 * http://dlang.org
 *
 * Copyright: Copyright (c) 1999-2016 by D Language Foundation, All Rights Reserved
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(DMDSRC root/_longdouble.d)
 */

module ddmd.root.longdouble;

real ldouble(T)(T x)
{
    return cast(real)x;
}

