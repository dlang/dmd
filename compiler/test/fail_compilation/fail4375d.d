// https://issues.dlang.org/show_bug.cgi?id=4375: Dangling else
/*
TEST_OUTPUT:
---
fail_compilation/fail4375d.d(14): Error: else is dangling, add { } after condition at fail_compilation/fail4375d.d(10)
---
*/

void main() {
    if (true)
label2:
        if (true)
            assert(15);
    else
        assert(16);
}
