/* https://issues.dlang.org/show_bug.cgi?id=22972
 */

int printf(const char *, ...);
void exit(int);

void assert(int b, int line)
{
    if (!b)
    {
        printf("failed test %d\n", line);
        exit(1);
    }
}

struct op {
    char text[4];
};

struct op ops[] = {
    {   "123" },
    {   "456" }
};

char *y = ops[1].text;
char *x[] = { ops[0].text };

int main()
{
    //printf("%c %c\n", *y, *x[0]);
    assert(*y == '4', 1);
    assert(*x[0] == '1', 2);
    return 0;
}
