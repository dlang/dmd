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

    assert(cs1[0]== 0, 1);
    assert(ds1[0]== 0, 2);
    assert(cs[1]== 0, 3);
    assert(ds[1]== 0, 4);
    assert(css.cs[1]== 0, 5);
    assert(dss.ds[1]== 0, 6);
    assert(csu.cs[1]== 0, 7);
    assert(dsu.ds[1]== 0, 8);
    assert(((char[2]){0})[1]== 0, 9);
    assert(((double[2]){0})[1]== 0, 10);

    return 0;
}
