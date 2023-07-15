// DISABLED: win32mscoff win64 freebsd

// https://issues.dlang.org/show_bug.cgi?id=23886

#include <stdlib.h>

int main()
{
    int *p = (int*)alloca(100 * sizeof(int));
    for (int i = 0; i < 100; ++i)
	p[i] = i;
    return 0;
}
