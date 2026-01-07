/*
TEST_OUTPUT:
---
---
*/

// https://issues.dlang.org/show_bug.cgi?id=22254

void main() 
{
    // This used to cause an ICE (Internal Compiler Error) in the backend
    assert(assert(0, ""), "");
}
