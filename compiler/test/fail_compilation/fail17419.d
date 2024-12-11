
// https://issues.dlang.org/show_bug.cgi?id=17419
/* TEST_OUTPUT:
---
fail_compilation/fail17419.d(14): Error: argument to `__traits(getLinkage, 64)` is not a declaration
enum s = __traits(getLinkage, 8 * 8);
         ^
fail_compilation/fail17419.d(15): Error: expected 1 arguments for `getLinkage` but had 2
enum t = __traits(getLinkage, 8, 8);
         ^
---
*/

enum s = __traits(getLinkage, 8 * 8);
enum t = __traits(getLinkage, 8, 8);
