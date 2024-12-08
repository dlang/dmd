/*
TEST_OUTPUT:
---
fail_compilation/fail257.d(12): Error: incompatible types for `("foo"d) == ("bar"c)`: `dstring` and `string`
pragma(msg, "foo"d == "bar"c ? "A" : "B");
            ^
fail_compilation/fail257.d(12):        while evaluating `pragma(msg, "foo"d == "bar"c ? "A" : "B")`
pragma(msg, "foo"d == "bar"c ? "A" : "B");
^
---
*/
pragma(msg, "foo"d == "bar"c ? "A" : "B");
