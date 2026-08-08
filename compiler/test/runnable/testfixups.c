#include <stdio.h>
#include <assert.h>

extern void funcextern();
       int funcglobal() { return 1; }
static int funcstatic() { return 2; }

int(*pfuncglobal)() = &funcglobal;
int(*pfuncstatic)()= &funcstatic;

extern int vextern;
       int vglobal = 3;
static int vstatic = 4;

extern _Thread_local int tlsextern;
       _Thread_local int tlsglobal = 5;
static _Thread_local int tlsstatic = 6;

       int* pvglobal = &vglobal;
static int* pvstatic = &vstatic;

int main()
{
    assert(funcglobal() == 1);
    assert(funcstatic() == 2);

    assert((*pfuncglobal)() == 1);
    assert((*pfuncstatic)() == 2);

    assert(vglobal == 3);
    assert(vstatic == 4);

    assert(tlsglobal == 5);
    assert(tlsstatic == 6);

    int* p;
    p = &vglobal;
    assert(*p == 3);
    p = &vstatic;
    assert(*p == 4);
    p = &tlsglobal;
    assert(*p == 5);
    p = &tlsstatic;
    assert(*p == 6);

    static int locstatic = 7;
    assert(locstatic == 7);

    assert(*pvglobal == 3);
    assert(*pvstatic == 4);

    return 0;
}
