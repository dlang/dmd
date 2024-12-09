/*
TEST_OUTPUT:
---
fail_compilation/fail22.d(15): Error: no identifier for declarator `char`
    foreach(char ; bug) {}
                 ^
---
*/

// infinite loop on DMD0.080

void main()
{
    char[] bug = "Crash";
    foreach(char ; bug) {}
}
