/*
TEST_OUTPUT:
---
fail_compilation/parse14745.d(15): Error: function literal cannot be `immutable`
    auto fp1 = function () pure immutable { return 0; };
                                          ^
fail_compilation/parse14745.d(16): Error: function literal cannot be `const`
    auto fp2 = function () pure const { return 0; };
                                      ^
---
*/

void test14745()
{
    auto fp1 = function () pure immutable { return 0; };
    auto fp2 = function () pure const { return 0; };
}
