// https://issues.dlang.org/show_bug.cgi?id=22286

int foo1(int);
int foo2(int, int);
typedef int Int;

void test()
{
    Int b;
    int x = (foo1)(3);
    x = (foo2)(3,4);
    x = (Int)(3);
    x = (Int)(3,4);
}
