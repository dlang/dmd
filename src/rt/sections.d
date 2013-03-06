/**
 *
 * Copyright: Copyright Digital Mars 2000 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly, Martin Nowak
 * Source: $(DRUNTIMESRC src/rt/_sections.d)
 */

module rt.sections;

version (linux)
    public import rt.sections_linux;
else version (FreeBSD)
    public import rt.sections_freebsd;
else version (OSX)
    public import rt.sections_osx;
else version (Win32)
    public import rt.sections_win32;
else version (Win64)
    public import rt.sections_win64;
else
    static assert(0, "unimplemented");

import rt.deh2, rt.minfo;

template isSectionGroup(T)
{
    enum isSectionGroup =
        is(typeof(T.init.modules) == ModuleInfo*[]) &&
        is(typeof(T.init.moduleGroup) == ModuleGroup) &&
        (!is(typeof(T.init.ehTables)) || is(typeof(T.init.ehTables) == immutable(FuncTable)[])) &&
        is(typeof({ foreach (ref T; T) {}})) &&
        is(typeof({ foreach_reverse (ref T; T) {}}));
}
static assert(isSectionGroup!(SectionGroup));
static assert(is(typeof(&initSections) == void function()));
static assert(is(typeof(&finiSections) == void function()));
