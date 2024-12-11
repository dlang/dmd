/*
TEST_OUTPUT:
---
fail_compilation/fail17689.d(12): Error: undefined identifier `x`
    assert(x==3);
           ^
---
*/
void main(){
    try{}
    finally int x=3;
    assert(x==3);
}
