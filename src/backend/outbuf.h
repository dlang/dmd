// Copyright (C) 1994-1998 by Symantec
// Copyright (C) 2000-2009 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in /dmd/src/dmd/backendlicense.txt
 * or /dm/src/dmd/backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

//#pragma once

#include        <string.h>

// Output buffer

// (This used to be called OutBuffer, we renamed it to avoid name conflicts with Mars.)

struct Outbuffer
{
    unsigned char *buf;         // the buffer itself
    unsigned char *pend;        // pointer past the end of the buffer
    unsigned char *p;           // current position in buffer
    unsigned len;               // size of buffer
    unsigned inc;               // default increment size

    Outbuffer();
    Outbuffer(unsigned inc);
    ~Outbuffer();
    void reset();

    // Reserve nbytes in buffer
    void reserve(unsigned nbytes);

    // Write n zeros; return pointer to start of zeros
    void *writezeros(unsigned n);

    // Position buffer to accept the specified number of bytes at offset
    int position(unsigned offset, unsigned nbytes);

    // Write an array to the buffer, no reserve check
    void writen(const void *b, int len)
    {
        memcpy(p,b,len);
        p += len;
    }

    // Clear bytes, no reserve check
    void clearn(int len)
    {
        int i;
        for (i=0; i< len; i++)
            *p++ = 0;
    }

    // Write an array to the buffer.
    void write(const void *b, int len);

    void write(Outbuffer *b) { write(b->buf,b->p - b->buf); }

    /**
     * Flushes the stream. This will write any buffered
     * output bytes.
     */
    void flush() { }

    /**
     * Writes an 8 bit byte, no reserve check.
     */
    void writeByten(char v)
    {
        *p++ = v;
    }

    /**
     * Writes an 8 bit byte.
     */
    void writeByte(int v);

    /**
     * Writes a 16 bit little-end short, no reserve check.
     */
    void writeWordn(int v)
    {
#if _WIN32
        *(unsigned short *)p = v;
#else
        p[0] = v;
        p[1] = v >> 8;
#endif
        p += 2;
    }


    /**
     * Writes a 16 bit little-end short.
     */
    void writeWord(int v)
    {
        reserve(2);
        writeWordn(v);
    }


    /**
     * Writes a 16 bit big-end short.
     */
    void writeShort(int v)
    {
        if (pend - p < 2)
            reserve(2);
#if 0
        p[0] = ((unsigned char *)&v)[1];
        p[1] = v;
#else
        unsigned char *q = p;
        q[0] = v >> 8;
        q[1] = v;
#endif
        p += 2;
    }

    /**
     * Writes a 16 bit char.
     */
    void writeChar(int v)
    {
        writeShort(v);
    }

    /**
     * Writes a 32 bit int.
     */
    void write32(int v);

    /**
     * Writes a 64 bit long.
     */
#if __INTSIZE == 4
    void write64(long long v);
#endif

    /**
     * Writes a 32 bit float.
     */
    void writeFloat(float v);

    /**
     * Writes a 64 bit double.
     */
    void writeDouble(double v);

    void write(const char *s);

    void write(const unsigned char *s);

    void writeString(const char *s);

    void prependBytes(const char *s);

    void prepend(const void *b, unsigned len);

    void bracket(char c1,char c2);

    /**
     * Returns the number of bytes written.
     */
    int size()
    {
        return p - buf;
    }

    char *toString();
    void setsize(unsigned size);

    void writesLEB128(int value);
    void writeuLEB128(unsigned value);

};
