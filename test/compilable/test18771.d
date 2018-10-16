// REQUIRED_ARGS : -c
// https://issues.dlang.org/show_bug.cgi?id=18771

import imports.test18771c, imports.test18771d;

static assert(__traits(isSame, fooC, fooD));
