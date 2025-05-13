// DISABLED: win freebsd openbsd

// https://issues.dlang.org/show_bug.cgi?id=23889

#include <alloca.h>

int main()
{
    int *p = (int*)alloca(100 * sizeof(int));
    for (int i = 0; i < 100; ++i)
	p[i] = i;
    return 0;
}
