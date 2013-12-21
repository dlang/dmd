/*
TEST_OUTPUT:
---
fail_compilation/fail218.d(15): Error: Cannot modify '", "'
---
*/

// Issue 1788 - dmd segfaults without info

void main()
{
    string a = "abc";
    double b = 7.5;

    a ~= ", " ~= b;
}
