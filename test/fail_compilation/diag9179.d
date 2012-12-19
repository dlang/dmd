/*
TEST_OUTPUT:
---
fail_compilation/diag9179.d(7): Error: must use !(T) syntax to instantiate template Pred(T)
fail_compilation/diag9179.d(7): Error: template diag9179.Pred(T) cannot deduce template function from argument types !()(int,int)
fail_compilation/diag9179.d(13): Error: template diag9179.func does not match any function template declaration. Candidates are:
fail_compilation/diag9179.d(6):        diag9179.func(T1, T2)(T1 t1, T2 t2) if (Pred(t1, t2))
fail_compilation/diag9179.d(13): Error: template diag9179.func(T1, T2)(T1 t1, T2 t2) if (Pred(t1, t2)) cannot deduce template function from argument types !()(int,int)
---
*/

#line 1
template Pred(T)
{
    enum Pred = true;
}

void func(T1, T2)(T1 t1, T2 t2)
    if (Pred(t1, t2))
{
}

void main()
{
    func(1, 2);
}
