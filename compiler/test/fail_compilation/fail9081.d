/*
TEST_OUTPUT:
---
fail_compilation/fail9081.d(18): Error: package `core` has no type
typeof(core) a;
       ^
fail_compilation/fail9081.d(19): Error: package `stdc` has no type
typeof(core.stdc) b;
           ^
fail_compilation/fail9081.d(20): Error: module `stdio` has no type
typeof(core.stdc.stdio) c;
                ^
---
*/

import core.stdc.stdio;

typeof(core) a;
typeof(core.stdc) b;
typeof(core.stdc.stdio) c;
