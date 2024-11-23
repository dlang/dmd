/* TEST_OUTPUT:
---
fail_compilation/testTypeof.c(14): Error: `typeof` operator expects an expression or type name in parentheses
typeof(1;2) x;
        ^
fail_compilation/testTypeof.c(14): Error: identifier or `(` expected
typeof(1;2) x;
          ^
fail_compilation/testTypeof.c(14): Error: expected identifier for declarator
fail_compilation/testTypeof.c(14): Error: expected identifier for declaration
---
*/

typeof(1;2) x;
