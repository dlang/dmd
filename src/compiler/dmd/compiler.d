
/* Written by Walter Bright
 * www.digitalmars.com
 * Placed into Public Domain
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
