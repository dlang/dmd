/**
 * Compiler implementation of the D programming language
 * http://dlang.org
 *
 * Copyright: Copyright (c) 1999-2016 by Digital Mars, All Rights Reserved
 * Authors:   Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(DMDSRC root/_rmem.d)
 */

module ddmd.root.rmem;

import core.stdc.string;
version = WithStack;
version (GC)
{
    import core.memory : GC;

    extern (C++) struct Mem
    {
        static char* xstrdup(const(char)* p) nothrow
        {
            return p[0 .. strlen(p) + 1].dup.ptr;
        }

        static void xfree(void* p) nothrow
        {
        }

        static void* xmalloc(size_t n) nothrow
        {
            return GC.malloc(n);
        }

        static void* xcalloc(size_t size, size_t n) nothrow
        {
            return GC.calloc(size * n);
        }

        static void* xrealloc(void* p, size_t size) nothrow
        {
            return GC.realloc(p, size);
        }
    }

    extern (C++) const __gshared Mem mem;
}
else
{
    import core.stdc.stdlib;
    import core.stdc.stdio;

    extern (C++) struct Mem
    {
        static char* xstrdup(const(char)* s) nothrow
        {
            if (s)
            {
                auto p = .strdup(s);
                if (p)
                    return p;
                error();
            }
            return null;
        }

        static void xfree(void* p) nothrow
        {
            if (p)
                .free(p);
        }

        static void* xmalloc(size_t size) nothrow
        {
            if (!size)
                return null;

            auto p = .malloc(size);
            if (!p)
                error();
            return p;
        }

        static void* xcalloc(size_t size, size_t n) nothrow
        {
            if (!size || !n)
                return null;

            auto p = .calloc(size, n);
            if (!p)
                error();
            return p;
        }

        static void* xrealloc(void* p, size_t size) nothrow
        {
            if (!size)
            {
                if (p)
                    .free(p);
                return null;
            }

            if (!p)
            {
                p = .malloc(size);
                if (!p)
                    error();
                return p;
            }

            p = .realloc(p, size);
            if (!p)
                error();
            return p;
        }

        static void error() nothrow
        {
            printf("Error: out of memory\n");
            exit(EXIT_FAILURE);
        }
    }

    extern (C++) const __gshared Mem mem;

    enum CHUNK_SIZE = (256 * 4096 - 64);


    __gshared size_t heapleft = 0;
    __gshared void* heapp;
	
    version(WithStack) {
        __gshared size_t stackleft = 0;
	    __gshared void* stacktop;
        __gshared void* stackbottom;
    }
    __gshared size_t* memleft = &heapleft;
    __gshared void** memp = &heapp;

    version (WithStack) {
        static assert(OVERRIDE_MEMALLOC, "Stacks will not work without using the costum alloc functions");

        /// returns the begin of the stack
        /// this is needed by endStack
        extern(C) void* beginStack(const size_t initialSize = CHUNK_SIZE) nothrow 
        {
        //    printf("BeginStackStart - in Stack: %d stackLeft: %d\n", memp != &heapp, stackleft);

            if (stackbottom) {
                if (stackleft < initialSize)
                {
                     allocmemory(initialSize);
                }
            } else {
                stackbottom = malloc(initialSize);
                stacktop = stackbottom;
                stackleft = initialSize;
            }


            memp = &stacktop;
            memleft = &stackleft;
      //      printf("BeginStackEnd - in Stack: %d - stackLeft: %d\n", memp != &heapp, stackleft);
     //       assert(0);
            return stacktop;
        }

        extern(C) void endStack(const void* stackBegin, ) nothrow
        {
            ptrdiff_t stacksize = (stacktop - stackBegin);
            assert(stacksize > 0);
            stackleft += stacksize;
            stacktop = stacktop - stacksize;

            if (stacktop == stackbottom) 
            {
                // if we discarded the last nesting stack
                // switch back to heap
                memp = &heapp;
                memleft = &heapleft;
            }
        }
    }
    extern (C) void* allocmemory(const size_t _m_size) nothrow
    {
        // 16 byte alignment is better (and sometimes needed) for doubles
        immutable m_size = (_m_size + 15) & ~15;

        // The layout of the code is selected so the most common case is straight through
  //      printf("StackMode : %d\n memLeft : %d\n", memp != &heapp, *memleft);
		if (m_size <= *memleft)
        {
        L1:
            *memleft -= m_size;
            auto p = (*memp);
            (*memp) = cast(void*)(cast(char*)p + m_size);
            return p;
        }

        if (memp == &heapp) {
            if (m_size > CHUNK_SIZE)
            {
                auto p = malloc(m_size);
                if (p)
                {
                    return p;
                }
                printf("Error: out of memory\n");
                exit(EXIT_FAILURE);
            }

            *memleft = CHUNK_SIZE;
           (*memp) = malloc(CHUNK_SIZE);
            if (!(*memp))
            {
                printf("Error: out of memory\n");
                exit(EXIT_FAILURE);
            }
        } else {
            version (WithStack) {
              //  stackbottom = realloc(stackbottom, stacksize + growBy);

   /*             if (!stackbottom) {
                    printf("Error: out of memory\n");
                    exit(EXIT_FAILURE);
                } */
                stacktop = stackbottom + (CHUNK_SIZE / 2);

//                stacktop = stackbottom + stacksize;
               stackleft = CHUNK_SIZE / 2;
            } else {
                assert(0, "We should never modify our memPtr without the Stack");
            }
        } 
        goto L1;
    }

    version (DigitalMars)
    {
        enum OVERRIDE_MEMALLOC = true;
    }
    else version (LDC)
    {
        // Memory allocation functions gained weak linkage when the @weak attribute was introduced.
        import ldc.attributes;
        enum OVERRIDE_MEMALLOC = is(typeof(ldc.attributes.weak));
    }
    else
    {
        enum OVERRIDE_MEMALLOC = false;
    }

    static if (OVERRIDE_MEMALLOC)
    {
        extern (C) void* _d_allocmemory(size_t m_size) nothrow
        {
            return allocmemory(m_size);
        }

        extern (C) Object _d_newclass(const ClassInfo ci) nothrow
        {
            auto p = allocmemory(ci.init.length);
            p[0 .. ci.init.length] = cast(void[])ci.init[];
            return cast(Object)p;
        }

        extern (C) void* _d_newitemT(TypeInfo ti) nothrow
        {
            auto p = allocmemory(ti.tsize);
            (cast(ubyte*)p)[0 .. ti.init.length] = 0;
            return p;
        }

        extern (C) void* _d_newitemiT(TypeInfo ti) nothrow
        {
            auto p = allocmemory(ti.tsize);
            p[0 .. ti.init.length] = ti.init[];
            return p;
        }
    }
}
