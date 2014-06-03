
/* Copyright (c) 2009-2014 by Digital Mars
 * All Rights Reserved, written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at http://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/D-Programming-Language/dmd/blob/master/src/root/async.h
 */

#ifndef ASYNC_H
#define ASYNC_H

#if __DMC__
#pragma once
#endif


/*******************
 * Simple interface to read files asynchronously in another
 * thread.
 */

struct AsyncRead
{
    static AsyncRead *create(size_t nfiles);
    void addFile(File *file);
    void start();
    int read(size_t i);
    static void dispose(AsyncRead *);
};


#endif
