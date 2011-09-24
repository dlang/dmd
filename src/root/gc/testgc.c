/* Digital Mars DMDScript source code.
 * Copyright (c) 2001-2007 by Digital Mars
 * All Rights Reserved, written by Walter Bright
 * http://www.digitalmars.com/dscript/cppscript.html
 *
 * This software is for evaluation purposes only.
 * It may not be redistributed in binary or source form,
 * incorporated into any product or program,
 * or used for any purpose other than evaluating it.
 * To purchase a license,
 * see http://www.digitalmars.com/dscript/cpplicense.html
 *
 * Use at your own risk. There is no warranty, express or implied.
 */

// GC tester program

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "gc.h"

void *stackbottom;

void printStats(GC *gc)
{
    GCStats stats;

    gc->getStats(&stats);
    printf("poolsize = x%x, usedsize = x%x, freelistsize = x%x, freeblocks = %d, pageblocks = %d\n",
        stats.poolsize, stats.usedsize, stats.freelistsize, stats.freeblocks, stats.pageblocks);
}

#define PERMUTE(key)    (key + 1)

void fill(void *p, unsigned key, unsigned size)
{
    unsigned i;
    char *q = (char *)p;

    for (i = 0; i < size; i++)
    {
        key = PERMUTE(key);
        q[i] = (char)key;
    }
}

void verify(void *p, unsigned key, unsigned size)
{
    unsigned i;
    char *q = (char *)p;

    for (i = 0; i < size; i++)
    {
        key = PERMUTE(key);
        assert(q[i] == (char)key);
    }
}

long desregs()
{
    return strlen("foo");
}

/* ---------------------------- */

void smoke()
{
    GC *gc;

    printf("--------------------------smoke()\n");

    gc = new GC();
    delete gc;

    gc = new GC();
    gc->init();
    delete gc;

    gc = new GC();
    gc->init();
    gc->setStackBottom(stackbottom);
    char *p = (char *)gc->malloc(10);
    assert(p);
    strcpy(p, "Hello!");
    char *p2 = gc->strdup(p);
    printf("p2 = %x, '%s'\n", p2, p2);
    int result = strcmp(p, p2);
    assert(result == 0);
    gc->strdup(p);

    printf("p  = %x\n", p);
    p = NULL;
    gc->fullcollect();
    printStats(gc);

    delete gc;
}

/* ---------------------------- */

void finalizer(void *p, void *dummy)
{
    (void)p;
    (void)dummy;
}

void smoke2()
{
    GC *gc;
    int *p;
    int i;

    #define SMOKE2_SIZE 100
    int *foo[SMOKE2_SIZE];

    printf("--------------------------smoke2()\n");

    gc = new GC();
    gc->init();
    gc->setStackBottom(stackbottom);

    for (i = 0; i < SMOKE2_SIZE; i++)
    {
        p = (int *)gc->calloc(i + 1, 500);
        p[0] = i * 3;
        foo[i] = p;
        gc->setFinalizer(p, finalizer);
    }

    for (i = 0; i < SMOKE2_SIZE; i += 2)
    {
        p = foo[i];
        if (p[0] != i * 3)
        {
            printf("p = %x, i = %d, p[0] = %d\n", p, i, p[0]);
            fflush(stdout);
        }
        assert(p[0] == i * 3);
        gc->free(p);
    }

    p = NULL;
    memset(foo, 0, sizeof(foo));

    gc->fullcollect();
    printStats(gc);

    delete gc;
}

/* ---------------------------- */

void smoke3()
{
    GC *gc;
    int *p;
    int i;

    printf("--------------------------smoke3()\n");

    gc = new GC();
    gc->init();
    gc->setStackBottom(stackbottom);

    for (i = 0; i < 1000000; i++)
//    for (i = 0; i < 1000; i++)
    {
        unsigned size = rand() % 2048;
        p = (int *)gc->malloc(size);
        memset(p, i, size);

        size = rand() % 2048;
        p = (int *)gc->realloc(p, size);
        memset(p, i + 1, size);
    }

    p = NULL;
    desregs();
    gc->fullcollect();
    printStats(gc);

    delete gc;
}

/* ---------------------------- */

void smoke4()
{
    GC *gc;
    int *p;
    int i;

    printf("--------------------------smoke4()\n");

    gc = new GC();
    gc->init();
    gc->setStackBottom(stackbottom);

    for (i = 0; i < 80000; i++)
    {
        unsigned size = i;
        p = (int *)gc->malloc(size);
        memset(p, i, size);

        size = rand() % 2048;
        gc->check(p);
        p = (int *)gc->realloc(p, size);
        memset(p, i + 1, size);
    }

    p = NULL;
    desregs();
    gc->fullcollect();
    printStats(gc);

    delete gc;
}

/* ---------------------------- */

void smoke5(GC *gc)
{
    char *p;
    int i;
    int j;
    #define SMOKE5_SIZE 1000
    char *array[SMOKE5_SIZE];
    unsigned offset[SMOKE5_SIZE];

    printf("--------------------------smoke5()\n");

    memset(array, 0, sizeof(array));
    memset(offset, 0, sizeof(offset));

    for (j = 0; j < 20; j++)
    {
        for (i = 0; i < 4000; i++)
        {
            unsigned size = (rand() % 2048) + 1;
            unsigned index = rand() % SMOKE5_SIZE;

            //printf("index = %d, size = %d\n", index, size);
            p = array[index] - offset[index];
            p = (char *)gc->realloc(p, size);
            if (array[index])
            {   unsigned s;

                //printf("\tverify = %d\n", p[0]);
                s = offset[index];
                if (size < s)
                    s = size;
                verify(p, index, s);
            }
            array[index] = p;
            fill(p, index, size);
            offset[index] = rand() % size;
            array[index] += offset[index];

            //printf("p[0] = %d\n", p[0]);
        }
        gc->fullcollect();
    }

    p = NULL;
    memset(array, 0, sizeof(array));
    gc->fullcollect();
    printStats(gc);
}

/* ---------------------------- */

/* ---------------------------- */

int main(int argc, char *argv[])
{
    GC *gc;

    printf("GC test start\n");

    (void)argc;
    stackbottom = &argv;

    gc = new GC();
    gc->init();
    gc->setStackBottom(stackbottom);

    smoke();
    smoke2();
    smoke3();
    smoke4();
    smoke5(gc);

    delete gc;

    printf("GC test success\n");
    return EXIT_SUCCESS;
}
