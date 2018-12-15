/* REQUIRED_ARGS: -m64
TEST_OUTPUT:
---
compilable/b16976.d(15): Deprecation: foreach: loop index implicitly converted from `size_t` to `int`
compilable/b16976.d(16): Deprecation: foreach: loop index implicitly converted from `size_t` to `int`
compilable/b16976.d(17): Deprecation: foreach: loop index implicitly converted from `size_t` to `char`
compilable/b16976.d(18): Deprecation: foreach: loop index implicitly converted from `size_t` to `char`
---
*/
void main()
{
    int[]  dyn = [1,2,3,4,5];
    int[5] sta = [1,2,3,4,5];

    foreach(int i, v; dyn) { }
    foreach_reverse(int i, v; dyn) { }
    foreach(char i, v; dyn) { }
    foreach_reverse(char i, v; dyn) { }
    foreach(int i, v; sta) { }
    foreach_reverse(int i, v; sta) { }
    foreach(char i, v; sta) { }
    foreach_reverse(char i, v; sta) { }
}
