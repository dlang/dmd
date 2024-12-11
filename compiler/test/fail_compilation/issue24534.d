/*
TEST_OUTPUT:
---
fail_compilation/issue24534.d(20): Error: `goto` skips declaration of variable `issue24534.f1.y1`
    goto Label1;
    ^
fail_compilation/issue24534.d(21):        declared here
    int y1;
        ^
fail_compilation/issue24534.d(28): Error: `goto` skips declaration of variable `issue24534.f2.y2`
    goto Label2;
    ^
fail_compilation/issue24534.d(30):        declared here
    int y2;
        ^
---
*/
void f1(){ //always failed with error about skipping a declaration
    int x1;
    goto Label1;
    int y1;
    Label1:
    int z1;
}

void f2(){ //compiled fine before this bug was fixed
    int x2;
    goto Label2;
    Dummy2:
    int y2;
    Label2:
    int z2;
}
