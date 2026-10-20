// EXTRA_FILES: c23attributes.c

// Compile-time verification of the D-observable effect of the C23 [[...]] attributes
// parsed from c23attributes.c. Only `deprecated` (C23 6.7.13.5) surfaces to the D
// frontend, via __traits(isDeprecated); the other standard attributes are accepted and
// ignored, and `noreturn` (6.7.13.7) is a backend codegen hint not visible to D.

import c23attributes;

// deprecated on functions: plain, with a message, the __attr__ spelling (6.7.13.1),
// within a multi-attribute list, and across two adjacent attribute-specifiers
static assert(__traits(isDeprecated, d1));
static assert(__traits(isDeprecated, d2));
static assert(__traits(isDeprecated, d3));
static assert(__traits(isDeprecated, m1));
static assert(__traits(isDeprecated, d4));

// C23 6.7.13.5 / 6.7.3.3 -- deprecated on an enumerator is applied to the D enum member;
// a member without it is not deprecated
static assert( __traits(isDeprecated, E.A));
static assert(!__traits(isDeprecated, E.B));
