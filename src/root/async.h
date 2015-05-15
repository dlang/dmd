
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
    // Creates a new instance of a AsyncRead. `nfiles` is maximum
    // number of files that can be queued for reading.
    static AsyncRead *create(size_t nfiles);

    // Queues a file for reading. Can only be called before `start()`.
    // Only `nfiles` can be added to the queue (`nfiles` is the
    // parameter to `create()`).
    void addFile(File *file);

    // Starts a background thread which reads (asynchronously) all queued files.
    void start();

    // Blocks the calling thread until the background thread
    // finishes reading the i-th file.
    int read(size_t i);

    // Frees the object returned by `AsyncRead::create()`. It is safe to call
    // only after `read()` is called for all queued files, because it doesn't
    // wait for the background thread to finish.
    static void dispose(AsyncRead *);
};


#endif
