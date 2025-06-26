/*
REQUIRED_ARGS: -unittest
TEST_OUTPUT:
---
AliasSeq!(__unittest221_1, __unittest221_2)
AliasSeq!(__unittest221_2)
---
*/
// https://issues.dlang.org/show_bug.cgi?id=21330

module test21330;

mixin template Test() {
    unittest {
    }
}

mixin Test;
mixin Test tm;

pragma(msg, __traits(getUnitTests, test21330));
pragma(msg, __traits(getUnitTests, tm));
