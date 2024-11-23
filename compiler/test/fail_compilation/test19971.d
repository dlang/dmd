/* TEST_OUTPUT:
---
fail_compilation/test19971.d(22): Error: function `f` is not callable using argument types `(string)`
    f("%s");
     ^
fail_compilation/test19971.d(22):        cannot pass argument `"%s"` of type `string` to parameter `int x`
fail_compilation/test19971.d(19):        `test19971.f(int x)` declared here
void f(int x) {}
     ^
fail_compilation/test19971.d(23): Error: function literal `__lambda_L23_C5(int x)` is not callable using argument types `(string)`
    (int x) {} ("%s");
               ^
fail_compilation/test19971.d(23):        cannot pass argument `"%s"` of type `string` to parameter `int x`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=19971

void f(int x) {}
void main()
{
    f("%s");
    (int x) {} ("%s");
}
