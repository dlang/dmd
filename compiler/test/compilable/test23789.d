// https://issues.dlang.org/show_bug.cgi?id=23789

import imports.c23789;

static assert(M128A.alignof == 64);
