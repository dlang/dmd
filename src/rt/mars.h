/**
 * Common declarations for runtime implementation.
 *
 * Copyright: Copyright Digital Mars 2000 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly
 */

/*          Copyright Digital Mars 2000 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
#include <stddef.h>

#if __cplusplus
extern "C" {
#endif

struct ClassInfo;
struct Vtbl;

typedef struct Vtbl
{
    size_t len;
    void **vptr;
} Vtbl;

typedef struct Interface
{
    struct ClassInfo *classinfo;
    struct Vtbl vtbl;
    int offset;
} Interface;

typedef struct Object
{
    void **vptr;
    void *monitor;
} Object;

typedef struct ClassInfo
{
    Object object;

    size_t initlen;
    void *init;

    size_t namelen;
    char *name;

    Vtbl vtbl;

    size_t interfacelen;
    Interface *interfaces;

    struct ClassInfo *baseClass;

    void *destructor;
    void *invariant;

    int flags;
} ClassInfo;

typedef struct Throwable
{
    Object object;

    size_t msglen;
    char*  msg;

    size_t filelen;
    char*  file;

    size_t line;

    struct Interface *info;
    struct Throwable *next;
} Throwable;

typedef struct Array
{
    size_t length;
    void *ptr;
} Array;

typedef struct Delegate
{
    void *thisptr;
    void (*funcptr)();
} Delegate;

void _d_monitorenter(Object *h);
void _d_monitorexit(Object *h);

int _d_isbaseof(ClassInfo *b, ClassInfo *c);
Object *_d_dynamic_cast(Object *o, ClassInfo *ci);

Object * _d_newclass(ClassInfo *ci);
void _d_delclass(Object **p);

void _d_OutOfMemory();

#if __cplusplus
}
#endif
