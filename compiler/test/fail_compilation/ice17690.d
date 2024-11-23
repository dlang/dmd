/*
TEST_OUTPUT:
---
fail_compilation/ice17690.d(11): Error: undefined identifier `x`
    assert(x==3);
           ^
---
*/
void main(){
    scope(exit) int x=3;
    assert(x==3);
}
