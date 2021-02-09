// Copyright (C) 1989-1998 by Symantec
// Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
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
