// REQUIRED_ARGS: -d
/*
TEST_OUTPUT:
---
fail_compilation/fail108.d(14): Error: typedef test1.foo circular definition
---
*/

// 249

module test1;

typedef foo bar;
typedef bar foo;

void main ()
{
    foo blah;
}
