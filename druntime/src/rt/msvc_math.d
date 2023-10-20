/**
 * Alternate implementations of single-precision math functions missing in at
 * least some 32-bit x86 MS VC runtime versions.
 * These alternate symbols are referenced in the rt.msvc module.
 *
 * Copyright: Copyright Digital Mars 2015.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Martin Kinkelin
 * Source:    $(DRUNTIMESRC rt/_msvc_math.d)
 */
module rt.msvc_math;

version (CRuntime_Microsoft):
version (X86):

import core.stdc.math;

extern(C):
@trusted:
nothrow:
@nogc:

mixin template AltImpl(string baseName)
{
    mixin("float _msvc_"~baseName~"f(float x) { return cast(float) "~baseName~"(x); }");
}
mixin template AltImpl2(string baseName)
{
    mixin("float _msvc_"~baseName~"f(float x, float y) { return cast(float) "~baseName~"(x, y); }");
}

mixin AltImpl!"acos";
mixin AltImpl!"asin";
mixin AltImpl!"atan";
mixin AltImpl2!"atan2";
mixin AltImpl!"cos";
mixin AltImpl!"sin";
mixin AltImpl!"tan";
mixin AltImpl!"cosh";
mixin AltImpl!"sinh";
mixin AltImpl!"tanh";
mixin AltImpl!"exp";
mixin AltImpl!"log";
mixin AltImpl!"log10";
mixin AltImpl2!"pow";
mixin AltImpl!"sqrt";
mixin AltImpl!"ceil";
mixin AltImpl!"floor";
mixin AltImpl2!"fmod";

float _msvc_modff(float value, float* iptr)
{
    double di;
    const result = cast(float) modf(value, &di);
    *iptr = cast(float) di;
    return result;
}
