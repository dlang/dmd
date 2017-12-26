/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/compiler.d, _compiler.d)
 * Documentation:  https://dlang.org/phobos/dmd_compiler.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/compiler.d
 */

module dmd.compiler;

import core.stdc.stdio;
import dmd.cond;
import dmd.globals;

struct Compiler
{
    const(char)* vendor; // Compiler backend name
}

/**
 * Add default `version` identifier for dmd, and set the
 * target platform in `global`.
 * https://dlang.org/spec/version.html#predefined-versions
 *
 * Needs to be run after all arguments parsing (command line, DFLAGS environment
 * variable and config file) in order to add final flags (such as `X86_64` or
 * the `CRuntime` used).
 */
void addDefaultVersionIdentifiers()
{
    VersionCondition.addPredefinedGlobalIdent("DigitalMars");
    static if (TARGET_WINDOS)
    {
        VersionCondition.addPredefinedGlobalIdent("Windows");
        global.params.isWindows = true;
    }
    else static if (TARGET_LINUX)
    {
        VersionCondition.addPredefinedGlobalIdent("Posix");
        VersionCondition.addPredefinedGlobalIdent("linux");
        VersionCondition.addPredefinedGlobalIdent("ELFv1");
        global.params.isLinux = true;
    }
    else static if (TARGET_OSX)
    {
        VersionCondition.addPredefinedGlobalIdent("Posix");
        VersionCondition.addPredefinedGlobalIdent("OSX");
        global.params.isOSX = true;
        // For legacy compatibility
        VersionCondition.addPredefinedGlobalIdent("darwin");
    }
    else static if (TARGET_FREEBSD)
    {
        VersionCondition.addPredefinedGlobalIdent("Posix");
        VersionCondition.addPredefinedGlobalIdent("FreeBSD");
        VersionCondition.addPredefinedGlobalIdent("ELFv1");
        global.params.isFreeBSD = true;
    }
    else static if (TARGET_OPENBSD)
    {
        VersionCondition.addPredefinedGlobalIdent("Posix");
        VersionCondition.addPredefinedGlobalIdent("OpenBSD");
        VersionCondition.addPredefinedGlobalIdent("ELFv1");
        global.params.isOpenBSD = true;
    }
    else static if (TARGET_SOLARIS)
    {
        VersionCondition.addPredefinedGlobalIdent("Posix");
        VersionCondition.addPredefinedGlobalIdent("Solaris");
        VersionCondition.addPredefinedGlobalIdent("ELFv1");
        global.params.isSolaris = true;
    }
    else
    {
        static assert(0, "fix this");
    }
    VersionCondition.addPredefinedGlobalIdent("LittleEndian");
    VersionCondition.addPredefinedGlobalIdent("D_Version2");
    VersionCondition.addPredefinedGlobalIdent("all");

    if (global.params.cpu >= CPU.sse2)
    {
        VersionCondition.addPredefinedGlobalIdent("D_SIMD");
        if (global.params.cpu >= CPU.avx)
            VersionCondition.addPredefinedGlobalIdent("D_AVX");
        if (global.params.cpu >= CPU.avx2)
            VersionCondition.addPredefinedGlobalIdent("D_AVX2");
    }

    if (global.params.is64bit)
    {
        VersionCondition.addPredefinedGlobalIdent("D_InlineAsm_X86_64");
        VersionCondition.addPredefinedGlobalIdent("X86_64");
        static if (TARGET_WINDOS)
        {
            VersionCondition.addPredefinedGlobalIdent("Win64");
        }
    }
    else
    {
        VersionCondition.addPredefinedGlobalIdent("D_InlineAsm"); //legacy
        VersionCondition.addPredefinedGlobalIdent("D_InlineAsm_X86");
        VersionCondition.addPredefinedGlobalIdent("X86");
        static if (TARGET_WINDOS)
        {
            VersionCondition.addPredefinedGlobalIdent("Win32");
        }
    }
    static if (TARGET_WINDOS)
    {
        if (global.params.mscoff)
            VersionCondition.addPredefinedGlobalIdent("CRuntime_Microsoft");
        else
            VersionCondition.addPredefinedGlobalIdent("CRuntime_DigitalMars");
    }
    else static if (TARGET_LINUX)
    {
        VersionCondition.addPredefinedGlobalIdent("CRuntime_Glibc");
    }

    if (global.params.isLP64)
        VersionCondition.addPredefinedGlobalIdent("D_LP64");
    if (global.params.doDocComments)
        VersionCondition.addPredefinedGlobalIdent("D_Ddoc");
    if (global.params.cov)
        VersionCondition.addPredefinedGlobalIdent("D_Coverage");
    if (global.params.pic)
        VersionCondition.addPredefinedGlobalIdent("D_PIC");
    if (global.params.useUnitTests)
        VersionCondition.addPredefinedGlobalIdent("unittest");
    if (global.params.useAssert == CHECKENABLE.on)
        VersionCondition.addPredefinedGlobalIdent("assert");
    if (global.params.useArrayBounds == CHECKENABLE.off)
        VersionCondition.addPredefinedGlobalIdent("D_NoBoundsChecks");
    if (global.params.betterC)
        VersionCondition.addPredefinedGlobalIdent("D_BetterC");

    VersionCondition.addPredefinedGlobalIdent("D_HardFloat");
}

void printPredefinedVersions()
{
    if (global.params.verbose && global.params.versionids)
    {
        fprintf(global.stdmsg, "predefs  ");
        foreach (const s; *global.params.versionids)
            fprintf(global.stdmsg, " %s", s);
        fprintf(global.stdmsg, "\n");
    }
}
