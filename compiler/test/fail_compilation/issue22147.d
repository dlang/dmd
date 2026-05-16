/*
TEST_OUTPUT:
---
fail_compilation/issue22147.d(15): Error: operator `/` is not defined for type `T`
fail_compilation/issue22147.d(9):        perhaps overload the operator with `auto opBinaryRight(string op : "/")(int lhs) {}`
---
*/

struct T
{
}

void test()
{
    auto result = 10 / T();  // int / T requires opBinaryRight on T
}
