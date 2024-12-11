/*
TEST_OUTPUT:
---
fail_compilation/diag10688.d(16): Error: function `diag10688.Bar.foo` `private` method is not virtual and cannot override
    override void foo() { }
                  ^
fail_compilation/diag10688.d(18): Error: function `diag10688.Bar.bar` `package` method is not virtual and cannot override
    override void bar() { }
                  ^
---
*/

class Bar
{
private:
    override void foo() { }
package:
    override void bar() { }
}
