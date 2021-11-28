/* TEST_OUTPUT:
---
fail_compilation/test22127.d(101): Error: user-defined attributes not allowed for `alias` declarations
---
 */

// https://issues.dlang.org/show_bug.cgi?id=22127

#line 100

alias getOne = @(0) function int () => 1;
