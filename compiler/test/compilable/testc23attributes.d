// EXTRA_FILES: c23attributes.c
/*
TEST_OUTPUT:
---
d1  [[deprecated]]               : true
d2  [[deprecated("msg")]]        : true
d3  [[__deprecated__]]           : true
m1  [[deprecated, maybe_unused]] : true
E.A [[deprecated("x")]]          : true
E.B (not deprecated)            : false
---
*/

// Compile-time verification (via __traits / pragma(msg)) of the D-observable effect of
// the C23 [[...]] attributes parsed from c23attributes.c. Only `deprecated`
// (C23 6.7.13.5) surfaces to the D frontend, via __traits(isDeprecated). The other
// standard attributes are accepted and ignored, and `noreturn` (6.7.13.7) is a backend
// codegen hint (dmd PR #12966) not visible to D, so none of those are introspectable.

import c23attributes;

// deprecated on functions: plain, with a message, the __attr__ spelling (6.7.13.1),
// and within a multi-attribute list
pragma(msg, "d1  [[deprecated]]               : ", __traits(isDeprecated, d1));
pragma(msg, "d2  [[deprecated(\"msg\")]]        : ", __traits(isDeprecated, d2));
pragma(msg, "d3  [[__deprecated__]]           : ", __traits(isDeprecated, d3));
pragma(msg, "m1  [[deprecated, maybe_unused]] : ", __traits(isDeprecated, m1));
static assert(__traits(isDeprecated, d1));
static assert(__traits(isDeprecated, d2));
static assert(__traits(isDeprecated, d3));
static assert(__traits(isDeprecated, m1));

// C23 6.7.13.5 / 6.7.3.3 -- deprecated on an enumerator is applied to the D enum member;
// a member without it is not deprecated
pragma(msg, "E.A [[deprecated(\"x\")]]          : ", __traits(isDeprecated, E.A));
pragma(msg, "E.B (not deprecated)            : ", __traits(isDeprecated, E.B));
static assert( __traits(isDeprecated, E.A));
static assert(!__traits(isDeprecated, E.B));
