#include <stdio.h>
#include <assert.h>

extern void funcextern();
static int funcglobal() { return 1; }
static int funcstatic() { return 2; }

extern int vextern;
       int vglobal = 3;
static int vstatic = 4;

extern _Thread_local int tlsextern;
       _Thread_local int tlsglobal = 5;
static _Thread_local int tlsstatic = 6;

int main()
{
    assert(funcglobal() == 1);
    assert(funcstatic() == 2);

    assert(vglobal == 3);
    assert(vstatic == 4);

    assert(tlsglobal == 5);
    assert(tlsstatic == 6);

    return 0;
}
