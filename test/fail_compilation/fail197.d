/*
TEST_OUTPUT:
---
fail_compilation/fail197.d(13): Error: function fail197.main.k!int._staticCtor2 static constructor can only be member of struct/class/module, not function main
fail_compilation/fail197.d(21): Error: mixin fail197.main.k!int error instantiating
---
*/

// 1510 ICE: Assertion failure: 'ad' on line 925 in file 'func.c'

template k(T)
{
    static this()
    {
        static assert(is(T:int));
    }
    void func(T t){}
}
void main()
{
    mixin k!(int);
}
