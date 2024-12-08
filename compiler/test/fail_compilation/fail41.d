/*
TEST_OUTPUT:
---
fail_compilation/fail41.d(19): Error: cannot return non-void from `void` function
        return mc;
        ^
---
*/

class MyClass
{
}

MyClass[char[]] myarray;

void fn()
{
    foreach (MyClass mc; myarray)
        return mc;
}
