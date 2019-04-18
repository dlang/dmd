/*
TEST_OUTPUT:
---
Error: cannot implicitly convert expression `<void>` of type `void` to `immutable(bool)`
---

*/
module ice19661;

immutable bool testModule = testFunctionMembers!();

void testFunctionMembers()() {
    import imports.imp19661 : isFunction;
    foreach(member; __traits(allMembers, ice19661)) {
        bool b = isFunction!(__traits(getMember, ice19661, member));
    }
}
