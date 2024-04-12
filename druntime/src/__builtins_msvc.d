/* This file contains D reimplementations of some of the intrinsics recognised
   by the MSVC compiler, for ImportC.
   This module is intended for only internal use, hence the leading double underscore.

   Copyright: Copyright D Language Foundation 2024-2024
   License: $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
   Authors: Harry Gillanders
   Source: $(DRUNTIMESRC __builtins_msvc.d) */

module __builtins_msvc;

version (CRuntime_Microsoft)
{
    version = MSVCIntrinsics;
}

version (MSVCIntrinsics)
{
    version (X86)
    {
        version = X86_64_Or_X86;
    }
    else version (X86_64)
    {
        version = X86_64_Or_X86;
        version = X86_64_Or_AArch64;
        version = X86_64_Or_AArch64_Or_ARM;
    }
    else version (AArch64)
    {
        version = X86_64_Or_AArch64;
        version = X86_64_Or_AArch64_Or_ARM;
        version = AArch64_Or_ARM;
    }
    else version (ARM)
    {
        version = X86_64_Or_AArch64_Or_ARM;
        version = AArch64_Or_ARM;
    }

    version (D_InlineAsm_X86)
    {
        version = InlineAsm_X86_64_Or_X86;
    }
    else version (D_InlineAsm_X86_64)
    {
        version = InlineAsm_X86_64_Or_X86;
    }

    version (LDC)
    {
        version = LDC_Or_GNU;
    }
    else version (GNU)
    {
        version = LDC_Or_GNU;
    }

    static if (__traits(compiles, () {import core.simd : float4;}))
    {
        private enum canPassVectors = true;
    }
    else
    {
        private enum canPassVectors = false;
    }
}
