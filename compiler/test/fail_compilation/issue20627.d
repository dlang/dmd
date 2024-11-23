/**
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/issue20627.d(62): Deprecation: `shared static` constructor can only be of D linkage
    shared static this () {}
    ^
fail_compilation/issue20627.d(63): Deprecation: `shared static` destructor can only be of D linkage
    shared static ~this () {}
    ^
fail_compilation/issue20627.d(64): Deprecation: `static` constructor can only be of D linkage
    static this () {}
    ^
fail_compilation/issue20627.d(65): Deprecation: `static` destructor can only be of D linkage
    static ~this () {}
    ^
fail_compilation/issue20627.d(79): Deprecation: `shared static` constructor can only be of D linkage
    shared static this () {}
    ^
fail_compilation/issue20627.d(80): Deprecation: `shared static` destructor can only be of D linkage
    shared static ~this () {}
    ^
fail_compilation/issue20627.d(81): Deprecation: `static` constructor can only be of D linkage
    static this () {}
    ^
fail_compilation/issue20627.d(82): Deprecation: `static` destructor can only be of D linkage
    static ~this () {}
    ^
fail_compilation/issue20627.d(87): Deprecation: `shared static` constructor can only be of D linkage
    shared static this () {}
    ^
fail_compilation/issue20627.d(88): Deprecation: `shared static` destructor can only be of D linkage
    shared static ~this () {}
    ^
fail_compilation/issue20627.d(89): Deprecation: `static` constructor can only be of D linkage
    static this () {}
    ^
fail_compilation/issue20627.d(90): Deprecation: `static` destructor can only be of D linkage
    static ~this () {}
    ^
---
*/

// OK, default linkage
shared static this () {}
shared static ~this () {}
static this () {}
static ~this () {}

// Still okay
extern(D)
{
    shared static this () {}
    shared static ~this () {}
    static this () {}
    static ~this () {}
}

// No!
extern(C)
{
    shared static this () {}
    shared static ~this () {}
    static this () {}
    static ~this () {}
}

// Disabled because platform specific
version (none) extern(Objective-C)
{
    shared static this () {}
    shared static ~this () {}
    static this () {}
    static ~this () {}
}

extern(C++)
{
    shared static this () {}
    shared static ~this () {}
    static this () {}
    static ~this () {}
}

extern(System)
{
    shared static this () {}
    shared static ~this () {}
    static this () {}
    static ~this () {}
}
