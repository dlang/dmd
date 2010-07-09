class MyClass
{
}

MyClass[char[]] myarray;

void fn()
{
    foreach (MyClass mc; myarray) return mc;
}

