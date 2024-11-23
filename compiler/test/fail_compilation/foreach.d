/*
TEST_OUTPUT:
---
fail_compilation/foreach.d(18): Error: cannot declare `out` loop variable, use `ref` instead
    foreach (out val; array) {}
             ^
fail_compilation/foreach.d(19): Error: cannot declare `out` loop variable, use `ref` instead
    foreach (out idx, out val; array) {}
             ^
fail_compilation/foreach.d(19): Error: cannot declare `out` loop variable, use `ref` instead
    foreach (out idx, out val; array) {}
                      ^
---
*/
void main ()
{
    int[] array;
    foreach (out val; array) {}
    foreach (out idx, out val; array) {}
}
