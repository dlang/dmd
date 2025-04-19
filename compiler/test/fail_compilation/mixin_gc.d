// REQUIRED_ARGS: -mixin=${RESULTS_DIR}/fail_compilation/mixin_test.mixin -lowmem
/*
TEST_OUTPUT:
---
{{RESULTS_DIR}}/fail_compilation/mixin_test.mixin($n$): Error: undefined identifier `b`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=1870
// https://issues.dlang.org/show_bug.cgi?id=12790
string get()
{
    return
    q{int x;
        int y;



        int z = x + b;};
}

void main()
{
    mixin(get());
}
