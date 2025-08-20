// https://issues.dlang.org/show_bug.cgi?id=4375: Dangling else
/*
TEST_OUTPUT:
---
fail_compilation/fail4375k.d-mixin-10(14): Error: else is dangling, add { } after condition at fail_compilation/fail4375k.d-mixin-10(11)
---
*/

void main() {
    mixin(q{
        if(true)
            if(true)
                assert(54);
        else
            assert(55);
    });
}
