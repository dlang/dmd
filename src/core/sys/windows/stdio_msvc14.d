/**
* This module provides MS VC runtime helper function to be used
* with VS versions VS 2015 or later
*
* Copyright: Copyright Digital Mars 2015.
* License: Distributed under the
*      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
*    (See accompanying file LICENSE)
* Source:    $(DRUNTIMESRC core/sys/windows/_stdio_msvc14.d)
* Authors:   Rainer Schuetze
*/

module core.sys.windows.stdio_msvc14;

version (CRuntime_Microsoft):

import core.stdc.stdio;

extern (C):
@system:
nothrow:
@nogc:

shared(FILE)* __acrt_iob_func(uint); // VS2015+

void init_msvc()
{
    stdin = __acrt_iob_func(0);
    stdout = __acrt_iob_func(1);
    stderr = __acrt_iob_func(2);
}

pragma(lib, "legacy_stdio_definitions.lib");

shared static this()
{
    // force linkage of ModuleInfo that includes the pragma(lib) above in its object file
}
