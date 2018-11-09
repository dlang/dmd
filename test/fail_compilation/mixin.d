// REQUIRED_ARGS: -mixin=test.mixin
// POST_SCRIPT: fail_compilation/extra-files/mixin-postscript.sh 
/*
TEST_OUTPUT:
---
test.mixin(7): Error: undefined identifier `b`
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
