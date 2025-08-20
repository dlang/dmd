// https://issues.dlang.org/show_bug.cgi?id=4375: Dangling else
/*
TEST_OUTPUT:
---
fail_compilation/fail4375h.d(15): Error: else is dangling, add { } after condition at fail_compilation/fail4375h.d(12)
---
*/

void main() {
    switch (4) {
        default:
            if (true)   // disallowed
                if (false)
                    assert(48);
            else
                assert(49);
            break;
    }
}
