/*
TEST_OUTPUT:
---
fail_compilation/diag9398.d(13): Error: incompatible types for `(f) : (s)`: `float` and `string`
    auto a = (true ? f : s);
              ^
---
*/
void main()
{
    float f;
    string s;
    auto a = (true ? f : s);
}
