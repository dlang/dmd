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
 *              Copyright (C) 1999-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/dlist.d, backend/dlist.d)
 */

module dmd.backend.dlist;

import core.stdc.stdarg;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;


nothrow:
@safe:
@nogc:

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

private __gshared list_t list_freelist;

/* **************** PUBLIC FUNCTIONS ********************* */

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
 * Prepend integer item to list.
 */

void list_prependdata(list_t *plist,int d)
{
    list_prepend(plist, null).data = d;
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
        list = list_new();
    }
    return list;
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

/********************************
 * Range for Lists.
 */
struct ListRange
{
  pure nothrow @nogc:

    this(list_t li)
    {
        this.li = li;
    }

    list_t front() return scope { return li; }
    void popFront() { li = li.next; }
    bool empty() const { return !li; }

  private:
    list_t li;
}
