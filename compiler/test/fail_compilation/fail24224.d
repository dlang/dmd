/+
TEST_OUTPUT:
---
fail_compilation/fail24224.d(25): Error: struct / class type expected as argument to __traits(initSymbol) instead of `ES`
    auto init1 = __traits(initSymbol, ES);
                 ^
fail_compilation/fail24224.d(26): Error: struct / class type expected as argument to __traits(initSymbol) instead of `EU`
    auto init2 = __traits(initSymbol, EU);
                 ^
fail_compilation/fail24224.d(27): Error: struct / class type expected as argument to __traits(initSymbol) instead of `EC`
    auto init3 = __traits(initSymbol, EC);
                 ^
---
+/
struct S {}
union U {}
class C {}

enum ES : S { a = S.init }
enum EU : U { a = U.init }
enum EC : C { a = C.init }

void test()
{
    auto init1 = __traits(initSymbol, ES);
    auto init2 = __traits(initSymbol, EU);
    auto init3 = __traits(initSymbol, EC);
}
