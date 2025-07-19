/*
TEST_OUTPUT:
---
fail_compilation/test21381.d(17): Error: `writeln` is not defined, perhaps `import std.stdio;` ?
fail_compilation/test21381.d(25): Error: undefined identifier `xyx`, did you mean struct `xyz`?
fail_compilation/test21381.d(31): Error: undefined identifier `NULL`, did you mean `null`?
fail_compilation/test21381.d(37): Error: undefined identifier `foo`
---
*/

enum plusOne(int x) = x + 1;

// tests typesem.d line:175
alias PlusOne1 =
  plusOne
	!
  writeln;

struct xyz{}

// tests typesem.d line:177
alias PlusOne3 =
	plusOne
	!
	xyx;

// tests typesem.d line:179
alias PlusOne4 =
	plusOne
	!
	NULL;

// tests typesem.d line:184
alias PlusOne2 =
	plusOne
	!
	foo;
