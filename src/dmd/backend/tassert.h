/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1989-1998 by Symantec
 *              Copyright (C) 2000-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/tassert.h, backend/tassert.h)
 */

//#pragma once
#ifndef TASSERT_H
#define TASSERT_H 1

/*****************************
 * Define a local assert function.
 */

#undef assert
#define assert(e)       ((e) || (local_assert(__LINE__), 0))

#if __clang__

void util_assert(const char * , int) __attribute__((noreturn));

__attribute__((noreturn)) static void local_assert(int line)
{
    util_assert(__file__,line);
    __builtin_unreachable();
}

#else

#if _MSC_VER
__declspec(noreturn)
#endif
void util_assert(const char *, int);

static void local_assert(int line)
{
    util_assert(__file__,line);
}

#if __DMC__
#pragma noreturn(util_assert)
#pragma noreturn(local_assert)
#endif

#endif


#endif /* TASSERT_H */
