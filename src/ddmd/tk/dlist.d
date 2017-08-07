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
 *              Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC backend/tk/_dlist.d)
 */

module tk.dlist;

extern (C++):
nothrow:
@nogc:

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

alias LIST* list_t;             /* pointer to a list entry              */

/* FPNULL is a null function pointer designed to be an argument to
 * list_free().
 */

alias void function(void*) list_free_fp;

enum FPNULL = cast(list_free_fp)null;

/* **************** PUBLIC VARIABLES ********************* */

extern int list_inited;         /* != 0 if list package is initialized  */

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
 *    pointer to previous item in list.
 */

list_t list_prev(list_t start, list_t list);

/********************************
 * Returns:
 *    ptr from list entry.
 */

void* list_ptr(list_t list) { return list.ptr; }

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

void list_init();

/*******************
 * Terminate list package.
 * Output:
 *      list_inited = 0
 */

void list_term();

/********************
 * Free list.
 * Params:
 *      plist =         Pointer to list to free
 *      freeptr =       Pointer to freeing function for the data pointer
 *                      (use FPNULL if none)
 * Output:
 *      *plist is null
 */

void list_free(list_t* plist, list_free_fp freeptr);

extern (C++) void list_free(list_t *l);

/***************************
 * Remove ptr from the list pointed to by *plist.
 * Output:
 *      *plist is updated to be the start of the new list
 * Returns:
 *      null if *plist is null
 *      otherwise ptr
 */

void* list_subtract(list_t* plist, void* ptr);

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

list_t list_append(list_t* plist, void* ptr);
list_t list_append_debug(list_t* plist, void* ptr, const(char)* file, int line);

/*************************
 * Prepend ptr to *plist.
 * Returns:
 *      pointer to list item created (which is also the start of the list).
 *      null if out of memory
 */

list_t list_prepend(list_t* plist, void* ptr);

/*************************
 * Count up and return number of items in list.
 * Returns:
 *      # of entries in list
 */

int list_nitems(list_t list);

/*************************
 * Returns:
 *    nth list entry in list.
 */

list_t list_nth(list_t list, int n);

/***********************
 * Returns:
 *    last list entry in list.
 */

list_t list_last(list_t list);

/***********************
 * Copy a list and return it.
 */

list_t list_copy(list_t list);

/************************
 * Compare two lists.
 * Returns:
 *      If they have the same ptrs, return 1 else 0.
 */

int list_equal(list_t list1, list_t list2);

/************************
 * Compare two lists using the comparison function fp.
 * The comparison function is the same as used for qsort().
 * Returns:
 *    If they compare equal, return 0 else value returned by fp.
 */

int list_cmp(list_t list1, list_t list2, int function(void*, void*) fp);

/*************************
 * Search for ptr in list.
 * Returns:
 *    If found, return list entry that it is, else null.
 */

list_t list_inlist(list_t list, void* ptr);

/*************************
 * Concatenate two lists (l2 appended to l1).
 * Output:
 *      *pl1 updated to be start of concatenated list.
 * Returns:
 *      *pl1
 */

list_t list_cat(list_t *pl1, list_t l2);

/*************************
 * Build a list out of the null-terminated argument list.
 * Returns:
 *      generated list
 */

list_t list_build(void* p, ...);

/***************************************
 * Apply a function fp to each member of a list.
 */

void list_apply(list_t* plist, void function(void*) fp);

/********************************************
 * Reverse a list.
 */

list_t list_reverse(list_t);

/**********************************************
 * Copy list of pointers into an array of pointers.
 */

void list_copyinto(list_t, void*);

/**********************************************
 * Insert item into list at nth position.
 */

list_t list_insert(list_t*, void*, int n);

