/**
 * Compiler information and associated routines.
 *
 * Copyright: Copyright Digital Mars 2000 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright
 */

/*          Copyright Digital Mars 2000 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.compiler;

// Identify the compiler used and its various features.

const
{
    // Vendor specific string naming the compiler
    char[] name = "Digital Mars D";

    // Master list of D compiler vendors
    enum Vendor
    {
        DigitalMars = 1
    }

    // Which vendor we are
    Vendor vendor = Vendor.DigitalMars;


    // The vendor specific version number, as in
    // version_major.version_minor
    uint version_major = 0;
    uint version_minor = 0;


    // The version of the D Programming Language Specification
    // Supported by the compiler
    uint D_major = 0;
    uint D_minor = 0;
}
