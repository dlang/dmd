// REQUIRED_ARGS: -d
/*
TEST_OUTPUT:
---
fail_compilation/fail108.d(14): Error: use alias instead of typedef
fail_compilation/fail108.d(15): Error: use alias instead of typedef
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
