/*
TEST_OUTPUT:
---
fail_compilation/fail161.d(108): Error: template instance `MetaString!"2 == 1"` does not match template declaration `MetaString(String)`
fail_compilation/fail161.d(108):        instantiated from here: `MetaString!"2 == 1"`
fail_compilation/fail161.d(101):        Candidate match: MetaString(String)
---
*/

#line 100

template MetaString(String)
{
    alias String Value;
}

void main()
{
    alias MetaString!("2 == 1") S;
    assert(mixin(S.Value));
}
