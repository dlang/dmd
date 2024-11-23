/* TEST_OUTPUT:
---
fail_compilation/test16443.d(14): Error: incompatible types for `(null) + (null)`: both operands are of type `typeof(null)`
    auto a = null + null;
             ^
fail_compilation/test16443.d(15): Error: incompatible types for `(null) - (null)`: both operands are of type `typeof(null)`
    auto b = null - null;
             ^
---
*/

void foo()
{
    auto a = null + null;
    auto b = null - null;
}
