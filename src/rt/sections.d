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

version (CRuntime_Glibc)
    public import rt.sections_elf_shared;
else version (FreeBSD)
    public import rt.sections_elf_shared;
else version (Solaris)
    public import rt.sections_solaris;
else version (OSX)
    public import rt.sections_osx;
else version (CRuntime_DigitalMars)
    public import rt.sections_win32;
else version (CRuntime_Microsoft)
    public import rt.sections_win64;
else version (CRuntime_Bionic)
    public import rt.sections_android;
else
    static assert(0, "unimplemented");

import rt.deh, rt.minfo;

template isSectionGroup(T)
{
    enum isSectionGroup =
        is(typeof(T.init.modules) == immutable(ModuleInfo*)[]) &&
        is(typeof(T.init.moduleGroup) == ModuleGroup) &&
        (!is(typeof(T.init.ehTables)) || is(typeof(T.init.ehTables) == immutable(FuncTable)[])) &&
        is(typeof(T.init.gcRanges) == void[][]) &&
        is(typeof({ foreach (ref T; T) {}})) &&
        is(typeof({ foreach_reverse (ref T; T) {}}));
}
static assert(isSectionGroup!(SectionGroup));
static assert(is(typeof(&initSections) == void function()));
static assert(is(typeof(&finiSections) == void function()));
static assert(is(typeof(&initTLSRanges) RT == return) &&
              is(typeof(&initTLSRanges) == RT function()) &&
              is(typeof(&finiTLSRanges) == void function(RT)) &&
              is(typeof(&scanTLSRanges) == void function(RT, scope void delegate(void*, void*) nothrow) nothrow));

version (Shared)
{
    static assert(is(typeof(&pinLoadedLibraries) == void* function() nothrow));
    static assert(is(typeof(&unpinLoadedLibraries) == void function(void*) nothrow));
    static assert(is(typeof(&inheritLoadedLibraries) == void function(void*)));
    static assert(is(typeof(&cleanupLoadedLibraries) == void function()));
}
