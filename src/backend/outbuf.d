/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1994-1998 by Symantec
 *              Copyright (c) 2000-2016 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     backendlicense.txt
 * Source:      $(DMDSRC backend/_outbuf.d)
 */

module ddmd.backend.outbuf;

import core.stdc.string;

// Output buffer

// (This used to be called OutBuffer, we renamed it to avoid name conflicts with Mars.)

extern (C++):

struct Outbuffer
{
    ubyte *buf;         // the buffer itself
    ubyte *pend;        // pointer past the end of the buffer
    ubyte *p;           // current position in buffer
    uint len;           // size of buffer
    uint inc;           // default increment size
    ubyte *origbuf;     // external buffer

    //this();

    this(size_t incx); // : buf(null), pend(null), p(null), len(0), inc(incx), origbuf(null) { }

    this(ubyte *bufx, size_t bufxlen, uint incx);
        //: buf(bufx), pend(bufx + bufxlen), p(bufx), len(bufxlen), inc(incx), origbuf(bufx) { }

    //~this();

    void reset();

    // Reserve nbytes in buffer
    void reserve(size_t nbytes)
    {
        if (pend - p < nbytes)
            enlarge(nbytes);
    }

    // Reserve nbytes in buffer
    void enlarge(size_t nbytes);

    // Write n zeros; return pointer to start of zeros
    void *writezeros(size_t n);

    // Position buffer to accept the specified number of bytes at offset
    void position(size_t offset, size_t nbytes);

    // Write an array to the buffer, no reserve check
    void writen(const void *b, size_t len)
    {
        memcpy(p,b,len);
        p += len;
    }

    // Clear bytes, no reserve check
    void clearn(size_t len)
    {
        for (size_t i = 0; i < len; i++)
            *p++ = 0;
    }

    // Write an array to the buffer.
    void write(const(void)* b, size_t len);

    void write(Outbuffer *b) { write(b.buf,b.p - b.buf); }

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
    void writeByte(int v)
    {
        if (pend == p)
            reserve(1);
        *p++ = cast(ubyte)v;
    }

    /**
     * Writes a 16 bit little-end short, no reserve check.
     */
    void writeWordn(int v)
    {
        version (LittleEndian)
        {
            *cast(ushort *)p = cast(ushort)v;
        }
        else
        {
            p[0] = v;
            p[1] = v >> 8;
        }
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
        ubyte *q = p;
        q[0] = cast(ubyte)(v >> 8);
        q[1] = cast(ubyte)v;
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
    void write64(long v);

    /**
     * Writes a 32 bit float.
     */
    void writeFloat(float v);

    /**
     * Writes a 64 bit double.
     */
    void writeDouble(double v);

    void write(const char *s);

    void write(const ubyte *s);

    void writeString(const char *s);

    void prependBytes(const char *s);

    void prepend(const void *b, size_t len);

    void bracket(char c1,char c2);

    /**
     * Returns the number of bytes written.
     */
    size_t size()
    {
        return p - buf;
    }

    char *toString();
    void setsize(size_t size);

    void writesLEB128(int value);
    void writeuLEB128(uint value);

}
