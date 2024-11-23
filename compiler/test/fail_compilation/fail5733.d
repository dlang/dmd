/*
TEST_OUTPUT:
---
fail_compilation/fail5733.d(14): Error: `opDispatch!"foo"` isn't a template
auto temp = Test().foo!(int);
                  ^
---
*/
struct Test
{
    struct opDispatch(string dummy)
    { enum opDispatch = 1; }
}
auto temp = Test().foo!(int);
