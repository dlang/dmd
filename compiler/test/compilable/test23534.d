// https://issues.dlang.org/show_bug.cgi?id=23534

enum E { a = 1, b = 2 }

// `E.a` is not 0
static assert(!__traits(isZeroInit, E));

// A static array of `E` is not all zero either
static assert(!__traits(isZeroInit, E[2]));
