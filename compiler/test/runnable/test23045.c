/* https://issues.dlang.org/show_bug.cgi?id=23045
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

void other(int a, int b)
{
    printf("a=%d b=%d\n", a, b);
    assert(a == 1, "1");
    assert(b == 2, "2");
}

int main()
{
    // called like extern(D)
    ((void (*)(int, int))other)(1, 2);

    // Error: incompatible types for `(cast(void function(int, int))& other) is (other)`: `void function(int, int)` and `extern (C) void(int a, int b)`
    if (((void (*)(int, int))other) == other)
	    {   }

    return 0;
}
