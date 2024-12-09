/*
TEST_OUTPUT:
---
fail_compilation/diag12487.d(27): Error: recursive expansion of template instance `diag12487.recTemplate!int`
    enum bool recTemplate = recTemplate!T;
                            ^
fail_compilation/diag12487.d(37): Error: template instance `diag12487.recTemplate!int` error instantiating
    enum bool value1 = recTemplate!int;
                       ^
fail_compilation/diag12487.d(30): Error: function `diag12487.recFunction` CTFE recursion limit exceeded
bool recFunction(int i)
     ^
fail_compilation/diag12487.d(32):        called from here: `recFunction(i)`
    return recFunction(i);
                      ^
fail_compilation/diag12487.d(30):        1000 recursive calls to function `recFunction`
bool recFunction(int i)
     ^
fail_compilation/diag12487.d(39):        called from here: `recFunction(0)`
    enum bool value2 = recFunction(0);
                                  ^
---
*/

template recTemplate(T)
{
    enum bool recTemplate = recTemplate!T;
}

bool recFunction(int i)
{
    return recFunction(i);
}

void main()
{
    enum bool value1 = recTemplate!int;

    enum bool value2 = recFunction(0);
}
