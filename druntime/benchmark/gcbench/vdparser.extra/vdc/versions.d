// This file is part of Visual D
//
// Visual D integrates the D programming language into Visual Studio
// Copyright (c) 2010-2011 by Rainer Schuetze, All Rights Reserved
//
// Distributed under the Boost Software License, Version 1.0.
// See accompanying file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt

module vdc.versions;

__gshared int[string] predefinedVersions;
alias AssociativeArray!(string, int) _wa1; // fully instantiate type info

static @property int[string] sPredefinedVersions()
{
    if(!predefinedVersions)
    {
        // see http://dlang.org/version.html
        //  1: always defined
        // -1: always undefined
        //  0: to be determined by compiler option
        predefinedVersions =
        [
            "DigitalMars" : 0,
            "GNU" : 0,
            "LDC" : 0,
            "SDC" : -1,
            "D_NET" : -1,

            "Windows" : 1,
            "Win32" : 0,
            "Win64" : 0,
            "linux" : -1,
            "OSX" : -1,
            "iOS" : -1,
            "TVOS" : -1,
            "WatchOS" : -1,
            "FreeBSD" : -1,
            "OpenBSD" : -1,
            "NetBSD" : -1,
            "DragonFlyBSD" : -1,
            "BSD" : -1,
            "Solaris" : -1,
            "Posix" : -1,
            "AIX" : -1,
            "Haiku" : -1,
            "SkyOS" : -1,
            "SysV3" : -1,
            "SysV4" : -1,
            "Hurd" : -1,
            "Android" : -1,
            "Cygwin" : -1,
            "MinGW" : -1,

            "X86" : 0,
            "X86_64" : 0,
            "ARM" : -1,
            "ARM_Thumb" : -1,
            "ARM_SoftFloat" : -1,
            "ARM_SoftFP" : -1,
            "ARM_HardFloat" : -1,
            "AArch64" : -1,
            "Epiphany" : -1,
            "PPC" : -1,
            "PPC_SoftFloat" : -1,
            "PPC_HardFloat" : -1,
            "PPC64" : -1,
            "IA64" : -1,
            "MIPS32" : -1,
            "MIPS64" : -1,
            "MIPS_O32" : -1,
            "MIPS_N32" : -1,
            "MIPS_O64" : -1,
            "MIPS_N64" : -1,
            "MIPS_EABI" : -1,
            "MIPS_SoftFloat" : -1,
            "MIPS_HardFloat" : -1,
            "NVPTX" : -1,
            "NVPTX64" : -1,
            "SPARC" : -1,
            "SPARC_V8Plus" : -1,
            "SPARC_SoftFloat" : -1,
            "SPARC_HardFloat" : -1,
            "SPARC64" : -1,
            "S390" : -1,
            "SystemZ" : -1,
            "HPPA" : -1,
            "HPPA64" : -1,
            "SH" : -1,
            "Alpha" : -1,
            "Alpha_SoftFloat" : -1,
            "Alpha_HardFloat" : -1,

            "LittleEndian" : 1,
            "BigEndian" : -1,

            "ELFv1" : -1,
            "ELFv2" : -1,

            "CRuntime_DigitalMars" : 0,
            "CRuntime_Microsoft" : 0,
            "CRuntime_Glibc" : -1,

            "D_Coverage" : 0,
            "D_Ddoc" : 0,
            "D_InlineAsm_X86" : 0,
            "D_InlineAsm_X86_64" : 0,
            "D_LP64" : 0,
            "D_X32" : -1,
            "D_HardFloat" : 1,
            "D_SoftFloat" : -1,
            "D_PIC" : -1,
            "D_SIMD" : 1,

            "D_Version2" : 1,
            "D_NoBoundsChecks" : 0,

            "unittest" : 0,
            "assert" : 0,

            "none" : -1,
            "all" : 1,
        ];
    }
    return predefinedVersions;
}
