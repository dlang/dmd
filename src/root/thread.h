
/* Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at http://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/D-Programming-Language/dmd/blob/master/src/root/thread.h
 */

#ifndef THREAD_H
#define THREAD_H 1

typedef long ThreadId;

struct Thread
{
    static ThreadId getId();
};

#endif
