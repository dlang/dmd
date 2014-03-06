
/* Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved, written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at http://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/D-Programming-Language/dmd/blob/master/src/root/file.h
 */

#ifndef FILE_H
#define FILE_H

#if __DMC__
#pragma once
#endif

#include <stddef.h>

#include "array.h"

typedef Array<struct File *> Files;

struct FileName;

struct File
{
    int ref;                    // != 0 if this is a reference to someone else's buffer
    unsigned char *buffer;      // data for our file
    size_t len;                 // amount of data in buffer[]
    void *touchtime;            // system time to use for file

    FileName *name;             // name of our file

    File(const char *);
    static File *create(const char *);
    File(const FileName *);
    ~File();

    char *toChars();

    /* Read file, return !=0 if error
     */

    int read();

    /* Read file, return !=0 if error
     */

    int mmread();

    /* Write file, return !=0 if error
     */

    int write();

    /* Return !=0 if file exists.
     *  0:      file doesn't exist
     *  1:      normal file
     *  2:      directory
     */

    /* Append to file, return !=0 if error
     */

    int append();

    /* Return !=0 if file exists.
     *  0:      file doesn't exist
     *  1:      normal file
     *  2:      directory
     */

    int exists();

    /* Given wildcard filespec, return an array of
     * matching File's.
     */

    static Files *match(char *);
    static Files *match(FileName *);

    // Compare file times.
    // Return   <0      this < f
    //          =0      this == f
    //          >0      this > f
    int compareTime(File *f);

    // Read system file statistics
    void stat();

    /* Set buffer
     */

    void setbuffer(void *buffer, size_t len)
    {
        this->buffer = (unsigned char *)buffer;
        this->len = len;
    }

    void remove();              // delete file
};

#endif
