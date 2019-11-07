void test1()
{    
    static void fun(int, int) {}

    static immutable int[5] a = [1, 2, 3, 4, 5];
    static foreach(i, v; a)
        fun(i, v);
}

void main()
{
    test1();
}
