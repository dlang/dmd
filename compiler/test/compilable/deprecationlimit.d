/*
REQUIRED_ARGS: -verrors=simple -verrors=3
TEST_OUTPUT:
---
compilable/deprecationlimit.d(21): Deprecation: function `deprecationlimit.f` is deprecated
compilable/deprecationlimit.d(15):        `f` is declared here
compilable/deprecationlimit.d(22): Deprecation: function `deprecationlimit.f` is deprecated
compilable/deprecationlimit.d(15):        `f` is declared here
compilable/deprecationlimit.d(23): Deprecation: function `deprecationlimit.f` is deprecated
compilable/deprecationlimit.d(15):        `f` is declared here
1 deprecation warning omitted, use `-verrors=0` to show all
---
*/

deprecated void f()
{
}

void main()
{
    f();
    f();
    f();
    static assert("1"); // also surpress deprecationSupplemental
}
