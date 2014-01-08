/*
TEST_OUTPUT:
---
fail_compilation/diag10862.d(13): Error: assignment cannot be used as a condition, perhaps == was meant?
fail_compilation/diag10862.d(14): Error: assignment cannot be used as a condition, perhaps == was meant?
fail_compilation/diag10862.d(15): Error: assignment cannot be used as a condition, perhaps == was meant?
---
*/

void main()
{
    int a, b;
    if ((a = b) = 0) { }
    if ((a = b) = (a = b)) { }
    if (a + b = a * b) { }
    semanticError;
}
