/* https://issues.dlang.org/show_bug.cgi?id=23028
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

int x;
void putx(int i) { x = i; }
int main()
{
    _Generic(1, int:putx(1), float:putx(2));
    assert(x == 1, 1);
    _Generic(1.0f, int:putx(1), float:putx(2));
    assert(x == 2, 2);
    return 0;
}
