/*
TEST_OUTPUT:
---
fail_compilation/diag8825.d(15): Error: undefined identifier `foo`
    t!(foo // line 13
    ^
---
*/

template t(alias a){
    alias int t;
}

void main(){
    t!(foo // line 13





    ) i; // line 19
    return;
}
