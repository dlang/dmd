// https://issues.dlang.org/show_bug.cgi?id=22885

typedef int T;
void test()
{
    typedef T* T;  // should declare a new T that is an int*
    int i;
    T p = &i;
}
