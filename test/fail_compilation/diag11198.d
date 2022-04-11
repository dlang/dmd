/*
TEST_OUTPUT:
---
fail_compilation/diag11198.d(11): Error: version `blah` declaration must be at module level
fail_compilation/diag11198.d(12): Error: debug `blah` declaration must be at module level
---
*/

void main()
{
    version = blah;
    debug = blah;
}
