// issues.dlang.org/show_bug.cgi?id=22755

void *malloc(unsigned);

void test()
{
    int *p = malloc(sizeof *p);
    int x = x;
}
