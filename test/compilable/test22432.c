// https://issues.dlang.org/show_bug.cgi?id=22432

struct S {
    int x;
};
typedef int T;
struct S F(struct S);

void test()
{
    struct S s;
    int x1 = (int)(s).x;
    int x2 = (T)(s).x;
    int x3 = (F)(s).x;
    struct S s1 = (F)(s);
    double d = 1.0;
    int x4 = (T)(d);
    int x5 = (T)(d)++;
    int x6 = (T)(d)--;
    struct S* p;
    int x7 = (T)(p)->x;
    int a[3];
    int x8 = (T)(a)[1]++;
}

