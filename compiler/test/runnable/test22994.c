/* https://issues.dlang.org/show_bug.cgi?id=22994
 */

int printf(const char *s, ...);
void exit(int);

void assert(int b, int line)
{
    if (!b)
    {
        printf("failed test %d\n", line);
        exit(1);
    }
}

char cs1[1];
double ds1[1];
char cs[2] = {0};
double ds[2] = {0.0};
struct { char cs[2]; } css = { {0} };
struct { double ds[2]; } dss = { {0} };
union { char cs[2]; } csu = { {0} };
union { double ds[2]; } dsu = { {0} };

int main()
{
    printf("%d\n", (int)cs1[0]);
    printf("%lf\n", ds1[0]);
    printf("%d\n", (int)cs[1]);
    printf("%lf\n", ds[1]);
    printf("%d\n", (int)css.cs[1]);
    printf("%lf\n", dss.ds[1]);
    printf("%d\n", (int)csu.cs[1]);
    printf("%lf\n", dsu.ds[1]);
    printf("%d\n", (int)((char[2]){0})[1]);
    printf("%lf\n", ((double[2]){0})[1]);

    assert(cs1[0]== 0, __LINE__);
    assert(ds1[0]== 0, __LINE__);
    assert(cs[1]== 0, __LINE__);
    assert(ds[1]== 0, __LINE__);
    assert(css.cs[1]== 0, __LINE__);
    assert(dss.ds[1]== 0, __LINE__);
    assert(csu.cs[1]== 0, __LINE__);
    assert(dsu.ds[1]== 0, __LINE__);
    assert(((char[2]){0})[1]== 0, __LINE__);
    assert(((double[2]){0})[1]== 0, __LINE__);

    return 0;
}
