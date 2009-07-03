// Copyright (C) 1989-1998 by Symantec
// Copyright (C) 2000-2009 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in /dmd/src/dmd/backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

//#pragma once
#ifndef TASSERT_H
#define TASSERT_H 1

/*****************************
 * Define a local assert function.
 */

#undef assert
#define assert(e)	((e) || (local_assert(__LINE__), 0))

void util_assert ( char * , int );
#pragma noreturn(util_assert)

static void local_assert(int line)
{
    util_assert(__file__,line);
}

#pragma noreturn(local_assert)

#endif /* TASSERT_H */
