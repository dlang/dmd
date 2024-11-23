/*
REQUIRED_ARGS: -o-
TEST_OUTPUT:
----
fail_compilation/fail7524a.d(11): Error: invalid filename for `#line` directive
#line 47 __DATE__
         ^
----
*/

#line 47 __DATE__
