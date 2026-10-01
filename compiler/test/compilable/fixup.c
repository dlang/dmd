/* tickle the ways of fixups */

#include <stdio.h>

extern int foo();

extern long long vextern;
long long vglobal;
static long long vstatic;

extern _Thread_local long long tlsextern;
_Thread_local long long tlsglobal;
_Thread_local static long long tlsstatic;

int main()
{
    printf("hello world %p %p %p %p %p %p\n", &vextern, &vglobal, &vstatic, &tlsextern, &tlsglobal, &tlsstatic);
    return 0;
}
