// https://issues.dlang.org/show_bug.cgi?id=23789

import imports.c23789;

static assert(M128A.alignof == 64);
static assert(_M128B.alignof == 32);
static assert(M128B.alignof == 32);

static assert(N128A.alignof == 64);
static assert(_N128B.alignof == 32);
static assert(N128B.alignof == 32);
