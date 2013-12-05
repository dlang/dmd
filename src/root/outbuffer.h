
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef OUTBUFFER_H
#define OUTBUFFER_H

#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <assert.h>
#include "port.h"
#include "rmem.h"

#if __DMC__
#pragma once
#endif

class RootObject;

struct OutBuffer
{
    unsigned char *data;
    size_t offset;
    size_t size;

    int doindent;
    int level;
    int notlinehead;

    OutBuffer();
    ~OutBuffer();
    char *extractData();

    void reserve(size_t nbytes);
    void setsize(size_t size);
    void reset();
    void write(const void *data, size_t nbytes);
    void writebstring(utf8_t *string);
    void writestring(const char *string);
    void prependstring(const char *string);
    void writenl();                     // write newline
    void writeByte(unsigned b);
    void writebyte(unsigned b) { writeByte(b); }
    void writeUTF8(unsigned b);
    void prependbyte(unsigned b);
    void writewchar(unsigned w);
    void writeword(unsigned w);
    void writeUTF16(unsigned w);
    void write4(unsigned w);
    void write(OutBuffer *buf);
    void write(RootObject *obj);
    void fill0(size_t nbytes);
    void align(size_t size);
    void vprintf(const char *format, va_list args);
    void printf(const char *format, ...);
    void bracket(char left, char right);
    size_t bracket(size_t i, const char *left, size_t j, const char *right);
    void spread(size_t offset, size_t nbytes);
    size_t insert(size_t offset, const void *data, size_t nbytes);
    void remove(size_t offset, size_t nbytes);
    char *toChars();
    char *extractString();
};

#endif
