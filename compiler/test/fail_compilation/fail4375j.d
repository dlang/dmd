// https://issues.dlang.org/show_bug.cgi?id=4375: Dangling else
/*
TEST_OUTPUT:
---
fail_compilation/fail4375j.d(15): Error: else is dangling, add { } after condition at fail_compilation/fail4375j.d(10)
---
*/

void main() {
    if (true)
        final switch (1)    // o_O
            case 1:
                if (false)
                    assert(119);
    else
        assert(120);
}
