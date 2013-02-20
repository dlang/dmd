/*
TEST_OUTPUT:
----
fail_compilation/ice9545.d(12): Error: T is not a field, but a alias
----
*/

struct S { template T(X) { alias T = X; } }

void main()
{
    auto x1 = S.init.T!int; // ICE
}
