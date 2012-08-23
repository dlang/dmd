/*
TEST_OUTPUT:
---
fail_compilation/diag8354.d(3): Error: must import std.math to use ^^ operator
fail_compilation/diag8354.d(5): Error: must import std.math to use ^^ operator
---
*/

#line 1
void main() {
    int x1 = 10;
    auto y1 = x1 ^^ 5;
    double x2 = 10.5;
    auto y2 = x2 ^^ 5;
}
