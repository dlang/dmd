/*
TEST_OUTPUT:
---
fail_compilation/fail45.d(12): Error: variable `fail45.main.O` cannot be declared to be a function
    typeof(main) O = 0;
                 ^
---
*/

void main()
{
    typeof(main) O = 0;
}
