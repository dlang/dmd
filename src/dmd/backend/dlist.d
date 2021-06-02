/**
 * Interface to the C linked list type.
 *
 * List is a complete package of functions to deal with singly linked
 * lists of pointers or integers.
 * Features:
 *      1. Uses mem package.
 *      2. Has loop-back tests.
 *      3. Each item in the list can have multiple predecessors, enabling
 *         different lists to 'share' a common tail.
 *
 * Copyright:   Copyright (C) 1986-1990 by Northwest Software
 *              Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/dlist.d, backend/dlist.d)
 */

module dmd.backend.dlist;

import core.stdc.stdarg;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

extern (C++):

nothrow:
@safe:
@nogc
{

/* **************** TYPEDEFS AND DEFINES ****************** */

struct LIST
{
        /* Do not access items in this struct directly, use the         */
        /* functions designed for that purpose.                         */
        LIST* next;             /* next element in list                 */
        int count;              /* when 0, element may be deleted       */
        union
        {       void* ptr;      /* data pointer                         */
                int data;
        }
}

alias list_t = LIST*;             /* pointer to a list entry              */

/* FPNULL is a null function pointer designed to be an argument to
 * list_free().
 */

alias list_free_fp = void function(void*) @nogc nothrow;

enum FPNULL = cast(list_free_fp)null;

/* **************** PUBLIC VARIABLES ********************* */

__gshared
{
    int list_inited;         // != 0 if list package is initialized
    list_t list_freelist;
    int nlist;
}

/* **************** PUBLIC FUNCTIONS ********************* */

/********************************
 * Create link to existing list, that is, share the list with
 * somebody else.
 *
 * Returns:
 *    pointer to that list entry.
 */

list_t list_link(list_t list)
{
    if (list)
        ++list.count;
    return list;
}

/********************************
 * Returns:
 *    pointer to next entry in list.
 */

list_t list_next(list_t list) { return list.next; }

/********************************
 * Returns:
 *    ptr from list entry.
 */

@trusted
inout(void)* list_ptr(inout list_t list) { return list.ptr; }

/********************************
 * Returns:
 *    integer item from list entry.
 */

int list_data(list_t list) { return list.data; }

/********************************
 * Append integer item to list.
 */

void list_appenddata(list_t* plist, int d)
{
    list_append(plist, null).data = d;
}

/********************************
 * Prepend integer item to list.
 */

void list_prependdata(list_t *plist,int d)
{
    list_prepend(plist, null).data = d;
}

/**********************
 * Initialize list package.
 * Output:
 *      list_inited = 1
 */

@trusted
void list_init()
{
    if (list_inited == 0)
    {
        nlist = 0;
        list_inited++;
    }
}

/*******************
 * Terminate list package.
 * Output:
 *      list_inited = 0
 */

@trusted
void list_term()
{
    if (list_inited)
    {
        debug printf("Max # of lists = %d\n",nlist);
        while (list_freelist)
        {
            list_t list = list_next(list_freelist);
            list_delete(list_freelist);
            list_freelist = list;
            nlist--;
        }
        debug if (nlist)
            printf("nlist = %d\n",nlist);
        assert(nlist == 0);
        list_inited = 0;
    }
}


@trusted
list_t list_alloc()
{
    list_t list;

    if (list_freelist)
    {
        list = list_freelist;
        list_freelist = list_next(list);
        //mem_setnewfileline(list,file,line);
    }
    else
    {
        nlist++;
        list = list_new();
    }
    return list;
}

list_t list_alloc(const(char)* file, int line)
{
    return list_alloc();
}


@trusted
list_t list_new() { return cast(list_t)malloc(LIST.sizeof); }

@trusted
void list_delete(list_t list) { free(list); }

/********************
 * Free list.
 * Params:
 *      plist =         Pointer to list to free
 *      freeptr =       Pointer to freeing function for the data pointer
 *                      (use FPNULL if none)
 * Output:
 *      *plist is null
 */

@trusted
void list_free(list_t* plist, list_free_fp freeptr)
{
    list_t list = *plist;
    *plist = null;             // block any circular reference bugs
    while (list && --list.count == 0)
    {
        list_t listnext = list_next(list);
        if (freeptr)
            (*freeptr)(list_ptr(list));
        debug memset(list, 0, (*list).sizeof);
        list.next = list_freelist;
        list_freelist = list;
        list = listnext;
    }
}

void list_free(list_t *l)
{
     list_free(l, FPNULL);
}

/***************************
 * Remove ptr from the list pointed to by *plist.
 * Output:
 *      *plist is updated to be the start of the new list
 * Returns:
 *      null if *plist is null
 *      otherwise ptr
 */

@trusted
void* list_subtract(list_t* plist, void* ptr)
{
    list_t list;

    while ((list = *plist) != null)
    {
        if (list_ptr(list) == ptr)
        {
            if (--list.count == 0)
            {
                *plist = list_next(list);
                list.next = list_freelist;
                list_freelist = list;
            }
            return ptr;
        }
        else
            plist = &list.next;
    }
    return null;            // it wasn't in the list
}

/***************************
 * Remove first element in list pointed to by *plist.
 * Returns:
 *      First element, null if *plist is null
 */

void* list_pop(list_t* plist)
{
    return list_subtract(plist, list_ptr(*plist));
}

/*************************
 * Append ptr to *plist.
 * Returns:
 *      pointer to list item created.
 *      null if out of memory
 */

@trusted
list_t list_append(list_t* plist, void* ptr)
{
    while (*plist)
        plist = &(*plist).next;   // find end of list

    list_t list = list_alloc();
    if (list)
    {
        *plist = list;
        list.next = null;
        list.ptr = ptr;
        list.count = 1;
    }
    return list;
}

list_t list_append_debug(list_t* plist, void* ptr, const(char)* file, int line)
{
    return list_append(plist, ptr);
}

/*************************
 * Prepend ptr to *plist.
 * Returns:
 *      pointer to list item created (which is also the start of the list).
 *      null if out of memory
 */

@trusted
list_t list_prepend(list_t *plist, void *ptr)
{
    list_t list = list_alloc();
    if (list)
    {
        list.next = *plist;
        list.ptr = ptr;
        list.count = 1;
        *plist = list;
    }
    return list;
}

/*************************
 * Count up and return number of items in list.
 * Returns:
 *      # of entries in list
 */

int list_nitems(list_t list)
{
    int n = 0;
    foreach (l; ListRange(list))
    {
        ++n;
    }
    return n;
}

/*************************
 * Returns:
 *    nth list entry in list.
 */

list_t list_nth(list_t list, int n)
{
    for (int i = 0; i < n; i++)
    {
        assert(list);
        list = list_next(list);
    }
    return list;
}

/***********************
 * Returns:
 *    last list entry in list.
 */

list_t list_last(list_t list)
{
    if (list)
        while (list_next(list))
            list = list_next(list);
    return list;
}

/********************************
 * Returns:
 *    pointer to previous item in list.
 */

list_t list_prev(list_t start, list_t list)
{
    if (start)
    {
        if (start == list)
            start = null;
        else
            while (list_next(start) != list)
            {
                start = list_next(start);
                assert(start);
            }
    }
    return start;
}

/***********************
 * Copy a list and return it.
 */

@trusted
list_t list_copy(list_t list)
{
    list_t c = null;
    for (; list; list = list_next(list))
        list_append(&c,list_ptr(list));
    return c;
}

/************************
 * Compare two lists.
 * Returns:
 *      If they have the same ptrs, return 1 else 0.
 */

int list_equal(list_t list1, list_t list2)
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

/************************
 * Compare two lists using the comparison function fp.
 * The comparison function is the same as used for qsort().
 * Returns:
 *    If they compare equal, return 0 else value returned by fp.
 */

@trusted
int list_cmp(list_t list1, list_t list2, int function(void*, void*) @nogc nothrow fp)
{
    int result = 0;

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
        result = (*fp)(list_ptr(list1),list_ptr(list2));
        if (result)
            break;
        list1 = list_next(list1);
        list2 = list_next(list2);
    }
    return result;
}

/*************************
 * Search for ptr in list.
 * Returns:
 *    If found, return list entry that it is, else null.
 */

@trusted
list_t list_inlist(list_t list, void* ptr)
{
    foreach (l; ListRange(list))
        if (l.ptr == ptr)
            return l;
    return null;
}

/*************************
 * Concatenate two lists (l2 appended to l1).
 * Output:
 *      *pl1 updated to be start of concatenated list.
 * Returns:
 *      *pl1
 */

list_t list_cat(list_t *pl1, list_t l2)
{
    list_t *pl;
    for (pl = pl1; *pl; pl = &(*pl).next)
    { }
    *pl = l2;
    return *pl1;
}

/***************************************
 * Apply a function fp to each member of a list.
 */

@trusted
void list_apply(list_t* plist, void function(void*) @nogc nothrow fp)
{
    if (fp)
        foreach (l; ListRange(*plist))
        {
            (*fp)(list_ptr(l));
        }
}

/********************************************
 * Reverse a list in place.
 */

list_t list_reverse(list_t l)
{
    list_t r = null;
    while (l)
    {
        list_t ln = list_next(l);
        l.next = r;
        r = l;
        l = ln;
    }
    return r;
}


/**********************************************
 * Copy list of pointers into an array of pointers.
 */

@trusted
void list_copyinto(list_t l, void *pa)
{
    void **ppa = cast(void **)pa;
    for (; l; l = l.next)
    {
        *ppa = l.ptr;
        ++ppa;
    }
}

/**********************************************
 * Insert item into list at nth position.
 */

@trusted
list_t list_insert(list_t *pl,void *ptr,int n)
{
    list_t list;

    while (n)
    {
        pl = &(*pl).next;
        n--;
    }
    list = list_alloc();
    if (list)
    {
        list.next = *pl;
        *pl = list;
        list.ptr = ptr;
        list.count = 1;
    }
    return list;
}

/********************************
 * Range for Lists.
 */
struct ListRange
{
  pure nothrow @nogc @safe:

    this(list_t li)
    {
        this.li = li;
    }

    list_t front() return  { return li; }
    void popFront() { li = li.next; }
    bool empty() const { return !li; }

  private:
    list_t li;
}

}

/* The following function should be nothrow @nogc, too, but on
 * some platforms core.stdc.stdarg is not fully nothrow @nogc.
 */

/*************************
 * Build a list out of the null-terminated argument list.
 * Returns:
 *      generated list
 */

@trusted
list_t list_build(void *p,...)
{
    va_list ap;

    list_t alist = null;
    list_t *pe = &alist;
    for (va_start(ap,p); p; p = va_arg!(void*)(ap))
    {
        list_t list = list_alloc();
        if (list)
        {
            list.next = null;
            list.ptr = p;
            list.count = 1;
            *pe = list;
            pe = &list.next;
        }
    }
    va_end(ap);
    return alist;
}


