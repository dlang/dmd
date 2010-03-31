/*_ list.c   Mon Oct 31 1994 */
/* Copyright (C) 1986-1994 by Symantec  */
/* All Rights Reserved                  */
/* Written by Walter Bright             */

#ifndef __STDIO_H
#include        <stdio.h>
#endif
#ifndef __STRING_H
#include        <string.h>
#endif
#ifndef __STDARG_H
#include        <stdarg.h>
#endif
#ifndef assert
#include        <assert.h>
#endif
#ifndef LIST_H
#include        "list.h"
#endif
#ifndef MEM_H
#include        "mem.h"
#endif

#if MEM_DEBUG
#define fileline        __FILE__,__LINE__
#else
#define fileline
#endif

#ifndef list_freelist
list_t list_freelist = NULL;    /* list of free list entries            */
#endif
static int nlist;               /* number of list items created         */
int list_inited = 0;            /* 1 if initialized                     */

/* Free storage allocation      */
#ifndef list_new

#if (__ZTC__ || __SC__) && !MEM_DEBUG
#define list_new()              ((list_t) mem_fmalloc(sizeof(struct LIST)))
#define list_delete(list)       mem_ffree(list)
#else
#if MEM_DEBUG
#define list_new()              ((list_t) mem_calloc_debug(sizeof(struct LIST),file,line))
#else
#define list_new()              ((list_t) mem_malloc(sizeof(struct LIST)))
#endif
#define list_delete(list)       mem_free(list)
#endif

#endif

/**********************/

void list_init()
{
#ifdef DEBUG
        assert(mem_inited);
#endif
        if (list_inited == 0)
        {       nlist = 0;
                list_inited++;
        }
}

/*******************/

void list_term()
{
        if (list_inited)
        {
#ifdef DEBUG
            printf("Max # of lists = %d\n",nlist);
#endif
            while (list_freelist)
            {   list_t list;

                list = list_next(list_freelist);
                list_delete(list_freelist);
                list_freelist = list;
                nlist--;
            }
#ifdef DEBUG
            if (nlist)
                printf("nlist = %d\n",nlist);
#endif
#if !MEM_DEBUG
            assert(nlist == 0);
#endif
            list_inited = 0;
        }
}

/****************************
 * Allocate list item.
 */

static list_t list_alloc
#if MEM_DEBUG
        (char *file,int line)
#else
        ()
#endif
{   list_t list;

    if (list_freelist)
    {   list = list_freelist;
        list_freelist = list_next(list);
#if MEM_DEBUG
        mem_setnewfileline(list,file,line);
#endif
    }
    else
    {   nlist++;
        list = list_new();
    }
    return list;
}

/******************************/

void list_free(list_t *plist,list_free_fp freeptr)
{       list_t list,listnext;

        list = *plist;
        *plist = 0;             /* block any circular reference bugs    */
        while (list && --list->count == 0)
        {       listnext = list_next(list);
                if (freeptr)
                        (*freeptr)(list_ptr(list));
#if DEBUG
                memset(list,0,sizeof(*list));
#endif
#if 1
                list->next = list_freelist;
                list_freelist = list;
#else
                list_delete(list);
                nlist--;
#endif
                list = listnext;
        }
}

/***************************/

void *list_subtract(list_t *plist,void *ptr)
{       list_t list;

        while ((list = *plist) != 0)
        {
                if (list_ptr(list) == ptr)
                {
                        if (--list->count == 0)
                        {       *plist = list_next(list);
                                list->next = list_freelist;
                                list_freelist = list;
                        }
                        return ptr;
                }
                else
                        plist = &(list_next(list));
        }
        return NULL;            /* it wasn't in the list                */
}

/*************************/

#if MEM_DEBUG
#undef list_append

list_t list_append(list_t *plist,void *ptr)
{
    return list_append_debug(plist,ptr,__FILE__,__LINE__);
}

list_t list_append_debug(list_t *plist,void *ptr,char *file,int line)
#else
list_t list_append(list_t *plist,void *ptr)
#endif
{       register list_t list;

        while (*plist)
                plist = &(list_next(*plist));   /* find end of list     */

#if MEM_DEBUG
        list = list_alloc(file,line);
#else
        list = list_alloc();
#endif
        if (list)
        {       *plist = list;
                list_next(list) = 0;
                list_ptr(list) = ptr;
                list->count = 1;
        }
        return list;
}

/*************************/

list_t list_prepend(list_t *plist,void *ptr)
{       register list_t list;

        list = list_alloc(fileline);
        if (list)
        {       list_next(list) = *plist;
                list_ptr(list) = ptr;
                list->count = 1;
                *plist = list;
        }
        return list;
}

/*************************/

#if __SC__ && __INTSIZE == 4 && _M_I86 && !_DEBUG_TRACE

__declspec(naked) int __pascal list_nitems(list_t list)
{
    _asm
    {
        mov     ECX,list-4[ESP]
        xor     EAX,EAX
        test    ECX,ECX
        jz      L1
    L2:
        mov     ECX,[ECX]LIST.next
        inc     EAX
        test    ECX,ECX
        jnz     L2
    L1:
        ret     4
    }
}

#else

#if __DMC__
int __pascal list_nitems(list_t list)
#else
int list_nitems(list_t list)
#endif
{       register int n;

        n = 0;
        while (list)
        {       n++;
                list = list_next(list);
        }
        return n;
}

#endif

/*************************/

list_t list_nth(list_t list,int n)
{       register int i;

        for (i = 0; i < n; i++)
        {       assert(list);
                list = list_next(list);
        }
        return list;
}

/*************************/

list_t list_last(list_t list)
{
        if (list)
                while (list_next(list))
                        list = list_next(list);
        return list;
}

/**************************/

list_t list_prev(list_t start,list_t list)
{
    if (start)
    {   if (start == list)
            start = NULL;
        else
            while (list_next(start) != list)
            {   start = list_next(start);
                assert(start);
            }
    }
    return start;
}

/****************************/

list_t list_copy(list_t list)
{   list_t c;

    c = NULL;
    for (; list; list = list_next(list))
        list_append(&c,list_ptr(list));
    return c;
}

/****************************/

int list_equal(list_t list1,list_t list2)
{
    while (list1 && list2)
    {
        if (list_ptr(list1) != list_ptr(list2))
            break;
        list1 = list_next(list1);
        list2 = list_next(list2);
    }
    return list1 == list2;
}

/****************************/

int list_cmp(list_t list1,list_t list2,int (*func)(void *,void *))
{   int result = 0;

    while (1)
    {
        if (!list1)
        {   if (list2)
                result = -1;    /* list1 < list2        */
            break;
        }
        if (!list2)
        {   result = 1;         /* list1 > list2        */
            break;
        }
        result = (*func)(list_ptr(list1),list_ptr(list2));
        if (result)
            break;
        list1 = list_next(list1);
        list2 = list_next(list2);
    }
    return result;
}

/*****************************/

list_t list_inlist(list_t list,void *ptr)
{
    for (; list; list = list_next(list))
        if (list_ptr(list) == ptr)
            break;
    return list;
}

/******************************/

list_t list_cat(list_t *pl1,list_t l2)
{   list_t *pl;

    for (pl = pl1; *pl; pl = &list_next(*pl))
        ;
    *pl = l2;
    return *pl1;
}

/******************************/

list_t list_build(void *p,...)
{   list_t alist;
    list_t *pe;
    va_list ap;

    alist = NULL;
    pe = &alist;
    for (va_start(ap,p); p; p = va_arg(ap,void *))
    {   list_t list;

        list = list_alloc(fileline);
        if (list)
        {       list_next(list) = NULL;
                list_ptr(list) = p;
                list->count = 1;
                *pe = list;
                pe = &list_next(list);
        }
    }
    va_end(ap);
    return alist;
}

/***************************************
 * Apply a function to each member of a list.
 */

void list_apply(list_t *plist,void (*fp)(void *))
{
    list_t l;

    if (fp)
        for (l = *plist; l; l = list_next(l))
        {
            (*fp)(list_ptr(l));
        }
}

/*********************************************
 * Reverse a list.
 */

list_t list_reverse(list_t l)
{   list_t r;
    list_t ln;

    r = NULL;
    while (l)
    {   ln = list_next(l);
        list_next(l) = r;
        r = l;
        l = ln;
    }
    return r;
}

/**********************************************
 * Copy list of pointers into an array of pointers.
 */

void list_copyinto(list_t l, void *pa)
{
    void **ppa = (void **)pa;
    for (; l; l = list_next(l))
        *(ppa)++ = list_ptr(l);
}

/**********************************************
 * Insert item into list at nth position.
 */

list_t list_insert(list_t *pl,void *ptr,int n)
{
    list_t list;

    while (n)
    {
        pl = &list_next(*pl);
        n--;
    }
    list = list_alloc(fileline);
    if (list)
    {
        list_next(list) = *pl;
        *pl = list;
        list_ptr(list) = ptr;
        list->count = 1;
    }
    return list;
}

#ifdef __cplusplus
void list_free(list_t *l) { list_free(l,FPNULL); }
#endif

