/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1994-1998 by Symantec
 *              Copyright (C) 2000-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/outbuf.d, backend/outbuf.d)
 */

module dmd.backend.outbuf;

// Online documentation: https://dlang.org/phobos/dmd_backend_outbuf.html

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.memory;

// Output buffer

// (This used to be called OutBuffer, we renamed it to avoid name conflicts with Mars.)

extern (C++):

struct Outbuffer
{
    ubyte *buf = null;         // the buffer itself
    ubyte *pend = null;        // pointer past the end of the buffer
    ubyte *p = null;           // current position in buffer
    ubyte *origbuf = null;     // external buffer

    static create()
    {
        return Outbuffer();
    }

    static Outbuffer create(size_t initialSize) // : buf(null), pend(null), p(null), origbuf(null) { }
    {
        Outbuffer buf;
        buf.buf = null;
        buf.pend = null;
        buf.p = null;
        buf.origbuf = null;

        buf.enlarge(cast(uint) initialSize);
        return buf;
    }

    static Outbuffer create(ubyte *bufx, size_t bufxlen, uint incx)
    {
        Outbuffer buf;
        buf.buf = bufx;
        buf.pend = bufx + bufxlen;
        buf.p = bufx;
        buf.origbuf = bufx;
        return buf;
    }

    ~this()
    {
        if (buf != origbuf)
        {
version (MEM_DEBUG)
{
            mem_free(buf);
}
else
{
            if (buf)
                free(buf);
}
        }

    }

    void reset()
    {
        p = buf;
    }

    // Reserve nbytes in buffer
    void reserve(uint nbytes)
    {
        if (pend - p < nbytes)
            enlarge(nbytes);
    }

    // Reserve nbytes in buffer
    void enlarge(uint nbytes)
    {
        const size_t oldlen = pend - buf;
        const size_t used = p - buf;

        size_t len = used + nbytes;
        if (len <= oldlen)
            return;

        const size_t newlen = oldlen + (oldlen >> 1);   // oldlen * 1.5
        if (len < newlen)
            len = newlen;
        len = (len + 15) & ~15;

version (MEM_DEBUG)
{
        if (buf == origbuf)
        {
            buf = cast(ubyte *) mem_malloc(len);
            if (buf)
                memcpy(buf, origbuf, oldlen);
        }
        else
            buf = cast(ubyte *)mem_realloc(buf, len);
}
else
{
         if (buf == origbuf && origbuf)
         {
             buf = cast(ubyte *) malloc(len);
             if (buf)
                 memcpy(buf, origbuf, used);
         }
         else
             buf = cast(ubyte *) realloc(buf,len);
}
        if (!buf)
        {
            fprintf(stderr, "Fatal Error: Out of memory");
            exit(EXIT_FAILURE);
        }

        pend = buf + len;
        p = buf + used;
    }

    // Write n zeros; return pointer to start of zeros
    void *writezeros(size_t len)
    {
        if (pend - p < len)
            reserve(cast(uint) len);
        void *pstart = memset(p,0,len);
        p += len;
        return pstart;
    }

    // Position buffer to accept the specified number of bytes at offset
    void position(size_t offset, size_t nbytes)
    {
        if (offset + nbytes > pend - buf)
        {
            enlarge(cast(uint) (offset + nbytes - (p - buf)));
        }
        p = buf + offset;
debug
{
        assert(buf <= p);
        assert(p <= pend);
        assert(p + nbytes <= pend);
}
    }

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
    void write(const(void)* b, uint len)
    {
        if (pend - p < len)
            reserve(len);
        memcpy(p,b,len);
        p += len;
    }

    void write(Outbuffer *b) { write(b.buf,cast(uint)(b.p - b.buf)); }

    /**
     * Flushes the stream. This will write any buffered
     * output bytes.
     */
    void flush() { }

    /**
     * Writes an 8 bit byte, no reserve check.
     */
    void writeByten(ubyte v)
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
    void write32(int v)
    {
        if (pend - p < 4)
            reserve(4);
        *cast(int *)p = v;
        p += 4;
    }

    /**
     * Writes a 64 bit long.
     */
    version (X86_64)
        private enum write64Mangle = "_ZN9Outbuffer7write64Ex";
    else
        private enum write64Mangle = "_ZN9Outbuffer7write64El";

    pragma(mangle, write64Mangle)
    void write64(long v)
    {
        if (pend - p < 8)
            reserve(8);
        *cast(long *)p = v;
        p += 8;
    }

    /**
     * Writes a 32 bit float.
     */
    void writeFloat(float v)
    {
        if (pend - p < float.sizeof)
            reserve(float.sizeof);
        *cast(float *)p = v;
        p += float.sizeof;
    }

    /**
     * Writes a 64 bit double.
     */
    void writeDouble(double v)
    {
        if (pend - p < double.sizeof)
            reserve(double.sizeof);
        *cast(double *)p = v;
        p += double.sizeof;
    }

    void write(const(char)* s)
    {
        write(s,cast(uint) strlen(s));
    }

    void write(const(ubyte)* s)
    {
        write(s,cast(uint) strlen(cast(const char *)s));
    }

    void writeString(const(char)* s)
    {
        write(s,cast(uint) (strlen(s)+1));
    }

    void prependBytes(const(char)* s)
    {
        prepend(s, strlen(s));
    }

    void prepend(const(void)* b, size_t len)
    {
        reserve(cast(uint) len);
        memmove(buf + len,buf,p - buf);
        memcpy(buf,b,len);
        p += len;
    }

    void bracket(char c1,char c2)
    {
        reserve(2);
        memmove(buf + 1,buf,p - buf);
        buf[0] = c1;
        p[1] = c2;
        p += 2;
    }

    /**
     * Returns the number of bytes written.
     */
    size_t size()
    {
        return p - buf;
    }

    char *toString()
    {
        if (pend == p)
            reserve(1);
        *p = 0;                     // terminate string
        return cast(char *)buf;
    }

    void setsize(size_t size)
    {
        p = buf + size;
debug
{
        assert(buf <= p);
        assert(p <= pend);
}
    }

    void writesLEB128(int value)
    {
        while (1)
        {
            ubyte b = value & 0x7F;

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

    void writeuLEB128(uint value)
    {
        do
        {   ubyte b = value & 0x7F;

            value >>= 7;
            if (value)
                b |= 0x80;
            writeByte(b);
        } while (value);
    }

}
