
// Copyright (c) 2009-2009 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

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
