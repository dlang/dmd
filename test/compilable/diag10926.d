/* TEST_OUTPUT:
---
---
*/
void main() {
    const(int)[] a, b;
    int[] c, d;
    (true ? a : c) ~= 20; // line 6, Error: a is not an lvalue
}
