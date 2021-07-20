/**
EXTRA_SOURCES: imports/test13197/a.d imports/test13197/y/package.d imports/test13197/y/z.d
*/
// https://issues.dlang.org/show_bug.cgi?id=13197
module issue13197;

import imports.test13197.a;

void test() { g(); }


