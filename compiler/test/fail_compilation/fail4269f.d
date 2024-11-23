/*
TEST_OUTPUT:
---
fail_compilation/fail4269f.d(11): Error: `alias X16 = X16;` cannot alias itself, use a qualified name to create an overload set
alias X16 X16;
^
---
*/

static if(is(typeof(X16))) {}
alias X16 X16;

void main() {}
