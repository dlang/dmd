// https://issues.dlang.org/show_bug.cgi?id=4375: Dangling else
/*
TEST_OUTPUT:
---
fail_compilation/fail4375i.d(15): Error: else is dangling, add { } after condition at fail_compilation/fail4375i.d(10)
---
*/

void main() {
    if (true)
        switch (1)  // o_O
            default:
                if (false)
                    assert(115);
    else
        assert(116);
}
