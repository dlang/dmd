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

