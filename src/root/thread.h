
/* Copyright (c) 2000-2014 by Digital Mars
 * All Rights Reserved, written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at http://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/dlang/dmd/blob/master/src/root/thread.h
 */

#ifndef THREAD_H
#define THREAD_H 1

typedef long ThreadId;

struct Thread
{
    static ThreadId getId();
};

#endif
