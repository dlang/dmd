/*_ exe4.c */
/* Copyright (C) 1986-1992 by Walter Bright             */
/* All Rights Reserved                                  */
/* Test alignment (compile with alignment off (-a))     */

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>

#undef strlen
#define __CLIB

typedef int (*PFI) (void);
typedef int (__CLIB *PFI2) (void);
typedef unsigned (__CLIB *PFC) (const char *);

int func1(void) { return 51; }
static int func2(void) { return 52; }
int func4(void),func5(void),atoi(const char*);

int callpfunc(PFC pf,char *s);

PFI array[] = {func1, func2, (PFI) strlen, func4};

void testpfunc()
{
        static int (*pfunc[])(void) = {func1,func2,(PFI)strlen,func4,func5,(PFI)atoi};
        static char L123[] = "123",L56[] = "56";
        int (__CLIB *pf)(void),i;
        int (*pf2)(void);
        PFI get_func();

        i = 0x10;
        assert(func1() == 51);
        assert(func2() == 52);
        assert(strlen(L123) == 3);
        assert(func4() == 54);
        assert(func5() == 55);
        assert(atoi(L56) == 56);

        assert((*pfunc[0])() == 51);
        assert((*pfunc[1])() == 52);
        assert((*(PFC)(pfunc[2]))(L123) == 3);
        assert((*pfunc[3])() == 54);
        assert((*pfunc[4])() == 55);
        assert((*(PFC)(pfunc[5]))(L56) == 56);

        //pf = (PFI2) strlen + 0x10;
        //assert((*((int (*)(char *))((char *)pf - i)))(L123) == 3);
        //pf -= i;
        //callpfunc((PFC)pf,"123");
        //callpfunc(strlen,"123");

        pf2 = get_func ();
        i = (*pf2) ();
        assert(i == 54);
        i = 0;
        i = pf2();
        assert(i == 54);

        pf2 = &func1;                   /* try alternative syntax       */
        assert(pf2() == 51);
}

/*static*/ int func4() { return 54; } // the static should work
int func5() { return 55; }

int callpfunc(pf,s)
PFC pf;
char *s;
{
        assert((*pf)(s) == 3);
}

PFI get_func ()
{
  return array[3];
}


/***************************************/

extern void PostASM();

void testp2()
{
    unsigned dist;
    static int cnt = 1;
    void (* post1)();
    void (* post2)();

    post1 = (void(*)())  ( ((unsigned char *)PostASM) +  6 );
    post2 = (void(*)())  ( ((unsigned char *)PostASM) + (6 * cnt) );
//    assert(post1 == post2); // doesn't work on Win32 for some reason
}

void PostASM() {}


/***************************************/

int main()
{
        printf("Test file '%s'\n",__FILE__);

        testpfunc();
        testp2();

        printf("Success\n");
        return EXIT_SUCCESS;
}
