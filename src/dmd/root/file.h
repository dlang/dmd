
/* Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * All Rights Reserved, written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/dmd/root/file.h
 */

#pragma once

#include <stddef.h>

#include "array.h"
#include "filename.h"

typedef Array<struct File *> Files;

struct File
{
    int ref;                    // != 0 if this is a reference to someone else's buffer
    unsigned char *buffer;      // data for our file
    size_t len;                 // amount of data in buffer[]

    FileName name;              // name of our file

    static File *create(const char *);
    ~File();

    const char *toChars() const;

    /* Read file, return true if error
     */

    bool read();

    /* Write file, return true if error
     */

    bool write();

    /* Set buffer
     */

    void setbuffer(void *buffer, size_t len)
    {
        this->buffer = (unsigned char *)buffer;
        this->len = len;
    }

    void remove();              // delete file
};
