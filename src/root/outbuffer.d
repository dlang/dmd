// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.root.outbuffer;

import core.stdc.stdarg, core.stdc.stdio, core.stdc.string;
import ddmd.root.rmem, ddmd.root.rootobject;

struct OutBuffer
{
    ubyte* data;
    size_t offset;
    size_t size;
    int doindent;
    int level;
    int notlinehead;

    extern (C++) ~this()
    {
        mem.xfree(data);
    }

    extern (C++) char* extractData()
    {
        char* p;
        p = cast(char*)data;
        data = null;
        offset = 0;
        size = 0;
        return p;
    }

    extern (C++) void reserve(size_t nbytes)
    {
        //printf("OutBuffer::reserve: size = %d, offset = %d, nbytes = %d\n", size, offset, nbytes);
        if (size - offset < nbytes)
        {
            size = (offset + nbytes) * 2;
            size = (size + 15) & ~15;
            data = cast(ubyte*)mem.xrealloc(data, size);
        }
    }

    extern (C++) void setsize(size_t size)
    {
        offset = size;
    }

    extern (C++) void reset()
    {
        offset = 0;
    }

    extern (C++) void write(const(void)* data, size_t nbytes)
    {
        if (doindent && !notlinehead)
        {
            if (level)
            {
                reserve(level);
                for (size_t i = 0; i < level; i++)
                {
                    this.data[offset] = '\t';
                    offset++;
                }
            }
            notlinehead = 1;
        }
        reserve(nbytes);
        memcpy(this.data + offset, data, nbytes);
        offset += nbytes;
    }

    extern (C++) void writebstring(char* string)
    {
        write(string, *string + 1);
    }

    extern (C++) void writestring(const(char)* string)
    {
        write(string, strlen(string));
    }

    extern (C++) void prependstring(const(char)* string)
    {
        size_t len = strlen(string);
        reserve(len);
        memmove(data + len, data, offset);
        memcpy(data, string, len);
        offset += len;
    }

    // write newline
    extern (C++) void writenl()
    {
        version (Windows)
        {
            writeword(0x0A0D); // newline is CR,LF on Microsoft OS's
        }
        else
        {
            writeByte('\n');
        }
        if (doindent)
            notlinehead = 0;
    }

    extern (C++) void writeByte(uint b)
    {
        if (doindent && !notlinehead && b != '\n')
        {
            if (level)
            {
                reserve(level);
                for (size_t i = 0; i < level; i++)
                {
                    this.data[offset] = '\t';
                    offset++;
                }
            }
            notlinehead = 1;
        }
        reserve(1);
        this.data[offset] = cast(ubyte)b;
        offset++;
    }

    extern (C++) void writeUTF8(uint b)
    {
        reserve(6);
        if (b <= 0x7F)
        {
            this.data[offset] = cast(ubyte)b;
            offset++;
        }
        else if (b <= 0x7FF)
        {
            this.data[offset + 0] = cast(ubyte)((b >> 6) | 0xC0);
            this.data[offset + 1] = cast(ubyte)((b & 0x3F) | 0x80);
            offset += 2;
        }
        else if (b <= 0xFFFF)
        {
            this.data[offset + 0] = cast(ubyte)((b >> 12) | 0xE0);
            this.data[offset + 1] = cast(ubyte)(((b >> 6) & 0x3F) | 0x80);
            this.data[offset + 2] = cast(ubyte)((b & 0x3F) | 0x80);
            offset += 3;
        }
        else if (b <= 0x1FFFFF)
        {
            this.data[offset + 0] = cast(ubyte)((b >> 18) | 0xF0);
            this.data[offset + 1] = cast(ubyte)(((b >> 12) & 0x3F) | 0x80);
            this.data[offset + 2] = cast(ubyte)(((b >> 6) & 0x3F) | 0x80);
            this.data[offset + 3] = cast(ubyte)((b & 0x3F) | 0x80);
            offset += 4;
        }
        else if (b <= 0x3FFFFFF)
        {
            this.data[offset + 0] = cast(ubyte)((b >> 24) | 0xF8);
            this.data[offset + 1] = cast(ubyte)(((b >> 18) & 0x3F) | 0x80);
            this.data[offset + 2] = cast(ubyte)(((b >> 12) & 0x3F) | 0x80);
            this.data[offset + 3] = cast(ubyte)(((b >> 6) & 0x3F) | 0x80);
            this.data[offset + 4] = cast(ubyte)((b & 0x3F) | 0x80);
            offset += 5;
        }
        else if (b <= 0x7FFFFFFF)
        {
            this.data[offset + 0] = cast(ubyte)((b >> 30) | 0xFC);
            this.data[offset + 1] = cast(ubyte)(((b >> 24) & 0x3F) | 0x80);
            this.data[offset + 2] = cast(ubyte)(((b >> 18) & 0x3F) | 0x80);
            this.data[offset + 3] = cast(ubyte)(((b >> 12) & 0x3F) | 0x80);
            this.data[offset + 4] = cast(ubyte)(((b >> 6) & 0x3F) | 0x80);
            this.data[offset + 5] = cast(ubyte)((b & 0x3F) | 0x80);
            offset += 6;
        }
        else
            assert(0);
    }

    extern (C++) void prependbyte(uint b)
    {
        reserve(1);
        memmove(data + 1, data, offset);
        data[0] = cast(ubyte)b;
        offset++;
    }

    extern (C++) void writewchar(uint w)
    {
        version (Windows)
        {
            writeword(w);
        }
        else
        {
            write4(w);
        }
    }

    extern (C++) void writeword(uint w)
    {
        version (Windows)
        {
            uint newline = 0x0A0D;
        }
        else
        {
            uint newline = '\n';
        }
        if (doindent && !notlinehead && w != newline)
        {
            if (level)
            {
                reserve(level);
                for (size_t i = 0; i < level; i++)
                {
                    this.data[offset] = '\t';
                    offset++;
                }
            }
            notlinehead = 1;
        }
        reserve(2);
        *cast(ushort*)(this.data + offset) = cast(ushort)w;
        offset += 2;
    }

    extern (C++) void writeUTF16(uint w)
    {
        reserve(4);
        if (w <= 0xFFFF)
        {
            *cast(ushort*)(this.data + offset) = cast(ushort)w;
            offset += 2;
        }
        else if (w <= 0x10FFFF)
        {
            *cast(ushort*)(this.data + offset) = cast(ushort)((w >> 10) + 0xD7C0);
            *cast(ushort*)(this.data + offset + 2) = cast(ushort)((w & 0x3FF) | 0xDC00);
            offset += 4;
        }
        else
            assert(0);
    }

    extern (C++) void write4(uint w)
    {
        version (Windows)
        {
            bool notnewline = w != 0x000A000D;
        }
        else
        {
            bool notnewline = true;
        }
        if (doindent && !notlinehead && notnewline)
        {
            if (level)
            {
                reserve(level);
                for (size_t i = 0; i < level; i++)
                {
                    this.data[offset] = '\t';
                    offset++;
                }
            }
            notlinehead = 1;
        }
        reserve(4);
        *cast(uint*)(this.data + offset) = w;
        offset += 4;
    }

    extern (C++) void write(OutBuffer* buf)
    {
        if (buf)
        {
            reserve(buf.offset);
            memcpy(data + offset, buf.data, buf.offset);
            offset += buf.offset;
        }
    }

    extern (C++) void write(RootObject obj)
    {
        if (obj)
        {
            writestring(obj.toChars());
        }
    }

    extern (C++) void fill0(size_t nbytes)
    {
        reserve(nbytes);
        memset(data + offset, 0, nbytes);
        offset += nbytes;
    }

    extern (C++) void vprintf(const(char)* format, va_list args)
    {
        int count;
        if (doindent)
            write(null, 0); // perform indent
        uint psize = 128;
        for (;;)
        {
            reserve(psize);
            version (Windows)
            {
                count = _vsnprintf(cast(char*)data + offset, psize, format, args);
                if (count != -1)
                    break;
                psize *= 2;
            }
            else version (Posix)
            {
                va_list va;
                va_copy(va, args);
                /*
                 The functions vprintf(), vfprintf(), vsprintf(), vsnprintf()
                 are equivalent to the functions printf(), fprintf(), sprintf(),
                 snprintf(), respectively, except that they are called with a
                 va_list instead of a variable number of arguments. These
                 functions do not call the va_end macro. Consequently, the value
                 of ap is undefined after the call. The application should call
                 va_end(ap) itself afterwards.
                 */
                count = vsnprintf(cast(char*)data + offset, psize, format, va);
                va_end(va);
                if (count == -1)
                    psize *= 2;
                else if (count >= psize)
                    psize = count + 1;
                else
                    break;
            }
            else
            {
                assert(0);
            }
        }
        offset += count;
    }

    extern (C++) void printf(const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        vprintf(format, ap);
        va_end(ap);
    }

    extern (C++) void bracket(char left, char right)
    {
        reserve(2);
        memmove(data + 1, data, offset);
        data[0] = left;
        data[offset + 1] = right;
        offset += 2;
    }

    /******************
     * Insert left at i, and right at j.
     * Return index just past right.
     */
    extern (C++) size_t bracket(size_t i, const(char)* left, size_t j, const(char)* right)
    {
        size_t leftlen = strlen(left);
        size_t rightlen = strlen(right);
        reserve(leftlen + rightlen);
        insert(i, left, leftlen);
        insert(j + leftlen, right, rightlen);
        return j + leftlen + rightlen;
    }

    extern (C++) void spread(size_t offset, size_t nbytes)
    {
        reserve(nbytes);
        memmove(data + offset + nbytes, data + offset, this.offset - offset);
        this.offset += nbytes;
    }

    /****************************************
     * Returns: offset + nbytes
     */
    extern (C++) size_t insert(size_t offset, const(void)* p, size_t nbytes)
    {
        spread(offset, nbytes);
        memmove(data + offset, p, nbytes);
        return offset + nbytes;
    }

    extern (C++) void remove(size_t offset, size_t nbytes)
    {
        memmove(data + offset, data + offset + nbytes, this.offset - (offset + nbytes));
        this.offset -= nbytes;
    }

    // Append terminating null if necessary and get view of internal buffer
    extern (C++) char* peekString()
    {
        if (!offset || data[offset - 1] != '\0')
        {
            writeByte(0);
            offset--; // allow appending more
        }
        return cast(char*)data;
    }

    // Append terminating null if necessary and take ownership of data
    extern (C++) char* extractString()
    {
        if (!offset || data[offset - 1] != '\0')
            writeByte(0);
        return extractData();
    }
}
