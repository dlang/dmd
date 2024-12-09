/*
REQUIRED_ARGS: -verrors=3
TEST_OUTPUT:
---
compilable/deprecationlimit.d(24): Deprecation: function `deprecationlimit.f` is deprecated
    f();
     ^
compilable/deprecationlimit.d(25): Deprecation: function `deprecationlimit.f` is deprecated
    f();
     ^
compilable/deprecationlimit.d(26): Deprecation: function `deprecationlimit.f` is deprecated
    f();
     ^
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
