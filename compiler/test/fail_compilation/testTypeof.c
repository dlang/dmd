/* TEST_OUTPUT:
---
fail_compilation/testTypeof.c(8): Error: `typeof` operator expects an expression or type name in parentheses
fail_compilation/testTypeof.c(8): Error: identifier or `(` expected
---
*/

typeof(1;2) x;
