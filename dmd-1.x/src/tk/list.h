/*_ list.h   Wed May 16 1990   Modified by: Walter Bright */
/* Copyright (C) 1986-1990 by Northwest Software        */
/* All Rights Reserved                                  */
/* Written by Walter Bright                             */

#ifndef LIST_H
#define LIST_H  1

#if __SC__
#pragma once
#endif

/*
 * List is a complete package of functions to deal with singly linked
 * lists of pointers or integers.
 * Features:
 *      o Uses mem package.
 *      o Has loop-back tests.
 *      o Each item in the list can have multiple predecessors, enabling
 *        different lists to 'share' a common tail.
 */

/***************** TYPEDEFS AND DEFINES *******************/

typedef struct LIST
{
        /* Do not access items in this struct directly, use the         */
        /* functions designed for that purpose.                         */
        struct LIST *next;      /* next element in list                 */
        int count;              /* when 0, element may be deleted       */
        union
        {       void *ptr;      /* data pointer                         */
                int data;
        } L;
} *list_t;                      /* pointer to a list entry              */

/* FPNULL is a null function pointer designed to be an argument to
 * list_free().
 */

typedef void (*list_free_fp) (void *);

#define FPNULL  ((list_free_fp) 0)

/***************** PUBLIC VARIABLES **********************/

extern int list_inited;         /* != 0 if list package is initialized  */

/***************** PUBLIC FUNCTIONS **********************/

/********************************
 * Create link to existing list, that is, share the list with
 * somebody else.
 * Use:
 *      list_t list_link(list_t list);
 * Returns:
 *      pointer to that list entry.
 */

#define list_link(list) (((list) && (list)->count++),(list))

/********************************
 * Return pointer to next entry in list.
 * Use:
 *      list_t list_next(list_t list);
 */

#define list_next(list) ((list)->next)

/********************************
 * Return pointer to previous item in list.
 * Use:
 *      list_t list_prev(list_t start,list_t list);
 */

/********************************
 * Return ptr from list entry.
 * Use:
 *      void *list_ptr(list_t list);
 */

#define list_ptr(list) ((list)->L.ptr)

/********************************
 * Return integer item from list entry.
 * Use:
 *      int list_data(list_t list);
 */

#define list_data(list) ((list)->L.data)

/********************************
 * Append integer item to list.
 * Use:
 *      void list_appenddata(list_t *plist,int d);
 */

#define list_appenddata(plist,d) (list_data(list_append((plist),NULL)) = (d))

/********************************
 * Prepend integer item to list.
 * Use:
 *      void list_prependdata(list_t *plist,int d);
 */

#define list_prependdata(plist,d) (list_data(list_prepend((plist),NULL)) = (d))

/**********************
 * Initialize list package.
 *      void list_init(void);
 * Output:
 *      list_inited = 1
 */

/*******************
 * Terminate list package.
 *      void list_term(void);
 * Output:
 *      list_inited = 0
 */

/********************
 * Free list.
 * Use:
 *      void list_free(list_t *plist,void (*freeptr)(void *));
 * Input:
 *      plist           Pointer to list to free
 *      freeptr         Pointer to freeing function for the data pointer
 *                      (use FPNULL if none)
 * Output:
 *      *plist is NULL
 */

/***************************
 * Remove ptr from the list pointed to by *plist.
 * Use:
 *      void *list_subtract(list_t *plist,void *ptr);
 * Output:
 *      *plist is updated to be the start of the new list
 * Returns:
 *      NULL if *plist is NULL
 *      otherwise ptr
 */

/***************************
 * Remove first element in list pointed to by *plist.
 *      void *list_pop(list_t *plist);
 * Returns:
 *      First element, NULL if *plist is NULL
 */

#define list_pop(plist) list_subtract((plist),list_ptr(*(plist)))

/*************************
 * Append ptr to *plist.
 * Use:
 *      list_t list_append(list_t *plist,void *ptr);
 * Returns:
 *      pointer to list item created.
 *      NULL if out of memory
 */

/*************************
 * Prepend ptr to *plist.
 * Use:
 *      list_t list_prepend(list_t *plist,void *ptr);
 * Returns:
 *      pointer to list item created (which is also the start of the list).
 *      NULL if out of memory
 */

/*************************
 * Count up and return number of items in list.
 * Use:
 *      int list_nitems(list_t list);
 * Returns:
 *      # of entries in list
 */

/*************************
 * Return nth list entry in list.
 * Use:
 *      list_t list_nth(list_t list,int n);
 */

/***********************
 * Return last list entry in list.
 * Use:
 *      list_t list_last(list_t list);
 */

/***********************
 * Copy a list and return it.
 * Use:
 *      list_t list_copy(list_t list);
 */

/************************
 * Compare two lists. If they have the same ptrs, return 1 else 0.
 * Use:
 *      int list_equal(list_t list1,list_t list2);
 */

/************************
 * Compare two lists using the specified comparison function.
 * If they compare equal, return 0 else value returned by func.
 * The comparison function is the same as used for qsort().
 */

int list_cmp (list_t list1,list_t list2,int (*func) (void *,void *));

/*************************
 * Search for ptr in list. If found, return list entry that it is, else NULL.
 * Use:
 *      list_t list_inlist(list_t list,void *ptr);
 */

/*************************
 * Concatenate two lists (l2 appended to l1).
 * Output:
 *      *pl1 updated to be start of concatenated list.
 * Returns:
 *      *pl1
 */

list_t list_cat (list_t *pl1, list_t l2);

/*************************
 * Build a list out of the NULL-terminated argument list.
 * Returns:
 *      generated list
 */

list_t list_build (void *p, ...);

/***************************************
 * Apply a function to each member of a list.
 */

void list_apply (list_t *plist,void (*fp)(void *));

/********************************************
 * Reverse a list.
 */

list_t list_reverse (list_t);

/**********************************************
 * Copy list of pointers into an array of pointers.
 */

void list_copyinto(list_t, void *);

/**********************************************
 * Insert item into list at nth position.
 */

list_t list_insert(list_t *,void *,int n);

/*********************** IMPLEMENTATION **********************/

extern  void list_init (void),
        list_term (void),
        list_free (list_t *,void (*)(void *));
extern  void *list_subtract (list_t *,void *);
extern  list_t
#if MEM_DEBUG
#define list_append(a,b) list_append_debug(a,b,__FILE__,__LINE__)
        list_append_debug (list_t *,void *,char *,int),
#else
        list_append (list_t *,void *),
#endif
        list_prepend (list_t *,void *),
        list_nth (list_t,int),
        list_last (list_t),
        list_prev (list_t,list_t),
        list_inlist (list_t,void *),
        list_copy (list_t);
#if __DMC__
extern  int __pascal list_nitems (list_t),
        list_equal (list_t,list_t);
#else
extern  int list_nitems (list_t),
        list_equal (list_t,list_t);
#endif

#ifdef __cplusplus
void list_free(list_t *l); // { list_free(l,FPNULL); }
#endif

#endif /* LIST_H */
