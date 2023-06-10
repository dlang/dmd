/* TEST_OUTPUT:
---
fail_compilation/test22339.c(101): Error: expression expected, not `.`
fail_compilation/test22339.c(101): Error: found `'a'` when expecting `}`
fail_compilation/test22339.c(101): Error: identifier or `(` expected
fail_compilation/test22339.c(102): Error: expression expected, not `.`
fail_compilation/test22339.c(102): Error: found `'\x03'` when expecting `}`
fail_compilation/test22339.c(102): Error: identifier or `(` expected
---
 */

// https://issues.dlang.org/show_bug.cgi?id=22339

#line 100

enum { A = .'a' };
enum { B = .'\x03' };
