// Copyright (C) 1994-1998 by Symantec
// Copyright (C) 2000-2013 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

// Output buffer

#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <stdio.h>

#include "cc.h"

#include "outbuf.h"
#include "mem.h"

#if DEBUG
static char __file__[] = __FILE__;      // for tassert.h
#include        "tassert.h"
#else
#include        <assert.h>
#endif

Outbuffer::Outbuffer()
{
    buf = NULL;
    pend = NULL;
    p = NULL;
    len = 0;
    inc = 0;
    origbuf = NULL;
}

Outbuffer::~Outbuffer()
{
    if (buf != origbuf)
    {
#if MEM_DEBUG
        mem_free(buf);
#else
        if (buf)
            free(buf);
#endif
    }
}

void Outbuffer::reset()
{
    p = buf;
}

// Enlarge buffer size so there's at least nbytes available
void Outbuffer::enlarge(size_t nbytes)
{
    size_t oldlen = len;
    size_t used = p - buf;

    if (inc > nbytes)
    {
        len = used + inc;
    }
    else
    {
        len = used + nbytes;
        if (len < 2 * oldlen)
        {   len = 2 * oldlen;
            if (len < 8)
                len = 8;
        }
    }
#if MEM_DEBUG
    if (buf == origbuf)
    {
        buf = (unsigned char *) mem_malloc(len);
        if (buf)
            memcpy(buf, origbuf, oldlen);
    }
    else
        buf = (unsigned char *)mem_realloc(buf, len);
#else
    if (buf)
    {
        if (buf == origbuf)
        {
            buf = (unsigned char *) malloc(len);
            if (buf)
                memcpy(buf, origbuf, oldlen);
        }
        else
            buf = (unsigned char *) realloc(buf,len);
    }
    else
        buf = (unsigned char *) malloc(len);
#endif
    if (!buf)
    {
        fprintf(stderr, "Fatal Error: Out of memory");
        exit(EXIT_FAILURE);
    }

    pend = buf + len;
    p = buf + used;
}

/*****************************************
 * Position buffer for output at a specified location and size.
 * Params:
 *      offset = specified location
 *      nbytes = number of bytes to be written at offset
 */
void Outbuffer::position(size_t offset, size_t nbytes)
{
    if (offset + nbytes > len)
    {
        enlarge(offset + nbytes - (p - buf));
    }
    p = buf + offset;
#if DEBUG
    assert(buf <= p);
    assert(p <= pend);
    assert(len == pend - buf);
    assert(p + nbytes <= pend);
#endif
}

// Write an array to the buffer.
void Outbuffer::write(const void *b, size_t len)
{
    if (pend - p < len)
        reserve(len);
    memcpy(p,b,len);
    p += len;
}

// Write n zeros to the buffer.
void *Outbuffer::writezeros(size_t len)
{
    if (pend - p < len)
        reserve(len);
    void *pstart = memset(p,0,len);
    p += len;
    return pstart;
}

/**
 * Writes a 32 bit int.
 */
void Outbuffer::write32(int v)
{
    if (pend - p < 4)
        reserve(4);
    *(int *)p = v;
    p += 4;
}

/**
 * Writes a 64 bit long.
 */

void Outbuffer::write64(long long v)
{
    if (pend - p < 8)
        reserve(8);
    *(long long *)p = v;
    p += 8;
}

/**
 * Writes a 32 bit float.
 */
void Outbuffer::writeFloat(float v)
{
    if (pend - p < sizeof(float))
        reserve(sizeof(float));
    *(float *)p = v;
    p += sizeof(float);
}

/**
 * Writes a 64 bit double.
 */
void Outbuffer::writeDouble(double v)
{
    if (pend - p < sizeof(double))
        reserve(sizeof(double));
    *(double *)p = v;
    p += sizeof(double);
}

/**
 * Writes a String as a sequence of bytes.
 */
void Outbuffer::write(const char *s)
{
    write(s,strlen(s));
}


/**
 * Writes a String as a sequence of bytes.
 */
void Outbuffer::write(const unsigned char *s)
{
    write(s,strlen((const char *)s));
}


/**
 * Writes a NULL terminated String
 */
void Outbuffer::writeString(const char *s)
{
    write(s,strlen(s)+1);
}

/**
 * Inserts string at beginning of buffer.
 */

void Outbuffer::prependBytes(const char *s)
{
    prepend(s, strlen(s));
}

void Outbuffer::prepend(const void *b, size_t len)
{
    reserve(len);
    memmove(buf + len,buf,p - buf);
    memcpy(buf,b,len);
    p += len;
}

/**
 */

void Outbuffer::bracket(char c1,char c2)
{
    reserve(2);
    memmove(buf + 1,buf,p - buf);
    buf[0] = c1;
    p[1] = c2;
    p += 2;
}

/**
 * Convert to a string.
 */

char *Outbuffer::toString()
{
    if (pend == p)
        reserve(1);
    *p = 0;                     // terminate string
    return (char *)buf;
}

/**
 * Set current size of buffer.
 */

void Outbuffer::setsize(size_t size)
{
    p = buf + size;
#if DEBUG
    assert(buf <= p);
    assert(p <= pend);
    assert(len == pend - buf);
#endif
}

void Outbuffer::writesLEB128(int value)
{
    while (1)
    {
        unsigned char b = value & 0x7F;

        value >>= 7;            // arithmetic right shift
        if (value == 0 && !(b & 0x40) ||
            value == -1 && (b & 0x40))
        {
             writeByte(b);
             break;
        }
        writeByte(b | 0x80);
    }
}

void Outbuffer::writeuLEB128(unsigned value)
{
    do
    {   unsigned char b = value & 0x7F;

        value >>= 7;
        if (value)
            b |= 0x80;
        writeByte(b);
    } while (value);
}

