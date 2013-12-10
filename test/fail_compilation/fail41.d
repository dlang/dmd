/*
TEST_OUTPUT:
---
fail_compilation/fail41.d(17): Error: cannot implicitly convert expression (mc) of type fail41.MyClass to void
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
