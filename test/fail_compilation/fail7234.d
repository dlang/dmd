/*
TEST_OUTPUT:
---
fail_compilation/fail7234.d(14): Error: template instance `opDispatch!"empty"` does not match template declaration `opDispatch()()`
---
*/

struct Contract {
    void opDispatch()(){}
}

void foo()
{
    Contract* r; if (r.empty) {}
}

