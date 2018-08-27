/**
 * D header file for interaction with Microsoft C++ <xutility>
 *
 * Copyright: Copyright (c) 2018 D Language Foundation
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Manu Evans
 * Source:    $(DRUNTIMESRC core/stdcpp/xutility.d)
 */

module core.stdcpp.xutility;

extern(C++, "std"):

version (CppRuntime_Microsoft)
{
    // Client code can mixin the set of MSVC linker directives
    mixin template MSVCLinkDirectives(bool failMismatch = false)
    {
        import core.stdcpp.xutility : __CXXLIB__;

        static if (__CXXLIB__ == "libcmtd")
        {
            pragma(lib, "libcpmtd");
            static if (failMismatch)
                pragma(linkerDirective, "/FAILIFMISMATCH:RuntimeLibrary=MTd_StaticDebug");
        }
        else static if (__CXXLIB__ == "msvcrtd")
        {
            pragma(lib, "msvcprtd");
            static if (failMismatch)
                pragma(linkerDirective, "/FAILIFMISMATCH:RuntimeLibrary=MDd_DynamicDebug");
        }
        else static if (__CXXLIB__ == "libcmt")
        {
            pragma(lib, "libcpmt");
            static if (failMismatch)
                pragma(linkerDirective, "/FAILIFMISMATCH:RuntimeLibrary=MT_StaticRelease");
        }
        else static if (__CXXLIB__ == "msvcrt")
        {
            pragma(lib, "msvcprt");
            static if (failMismatch)
                pragma(linkerDirective, "/FAILIFMISMATCH:RuntimeLibrary=MD_DynamicRelease");
        }
    }

    // convenient alias for the C++ std library name
    enum __CXXLIB__ = __traits(getTargetInfo, "cppRuntimeLibrary");

package:
    // these are all [[noreturn]]
    void _Xbad() nothrow @trusted @nogc;
    void _Xinvalid_argument(const(char)* message) nothrow @trusted @nogc;
    void _Xlength_error(const(char)* message) nothrow @trusted @nogc;
    void _Xout_of_range(const(char)* message) nothrow @trusted @nogc;
    void _Xoverflow_error(const(char)* message) nothrow @trusted @nogc;
    void _Xruntime_error(const(char)* message) nothrow @trusted @nogc;
}
