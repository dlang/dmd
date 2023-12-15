/* TEST_OUTPUT:
---
fail_compilation/testTypeof.c(10): Error: `typeof` operator expects an expression or type name in parentheses
fail_compilation/testTypeof.c(10): Error: identifier or `(` expected
fail_compilation/testTypeof.c(10): Error: expected identifier for declarator
fail_compilation/testTypeof.c(10): Error: expected identifier for declaration
---
*/

typeof(1;2) x;
