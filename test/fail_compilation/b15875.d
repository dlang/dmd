/* TEST_OUTPUT:
---
fail_compilation/b15875.d(7): Error: circular reference to variable `a`
---
*/
// https://issues.dlang.org/show_bug.cgi?id=15875
d o(int[a]a)(){}
