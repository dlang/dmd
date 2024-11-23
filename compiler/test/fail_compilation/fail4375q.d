// REQUIRED_ARGS: -w
// https://issues.dlang.org/show_bug.cgi?id=4375: Dangling else
/*
TEST_OUTPUT:
---
fail_compilation/fail4375q.d(21): Warning: else is dangling, add { } after condition at fail_compilation/fail4375q.d(17)
    else
    ^
fail_compilation/fail4375q.d(18): Error: `with` expression types must be enums or aggregates or pointers to them, not `int`
        with (x)
        ^
---
*/

void main() {
    auto x = 1;
    if (true)
        with (x)
            if (false)
                assert(90);
    else
        assert(91);
}
