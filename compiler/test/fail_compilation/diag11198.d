/*
TEST_OUTPUT:
---
fail_compilation/diag11198.d(33): Error: version `blah` declaration must be at module level
    version = blah;
              ^
fail_compilation/diag11198.d(34): Error: debug `blah` declaration must be at module level
    debug = blah;
            ^
fail_compilation/diag11198.d(35): Deprecation: `version = <integer>` is deprecated, use version identifiers instead
    version = 1;
              ^
fail_compilation/diag11198.d(35): Error: version `1` level declaration must be at module level
    version = 1;
              ^
fail_compilation/diag11198.d(36): Deprecation: `debug = <integer>` is deprecated, use debug identifiers instead
    debug = 2;
            ^
fail_compilation/diag11198.d(36): Error: debug `2` level declaration must be at module level
    debug = 2;
            ^
fail_compilation/diag11198.d(37): Error: identifier or integer expected, not `""`
    version = "";
              ^
fail_compilation/diag11198.d(38): Error: identifier or integer expected, not `""`
    debug = "";
            ^
---
*/

void main()
{
    version = blah;
    debug = blah;
    version = 1;
    debug = 2;
    version = "";
    debug = "";
}
