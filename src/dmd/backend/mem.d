/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/tk.d backend/tk.d)
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/tk.d
 */

module dmd.backend.mem;

import core.stdc.stdarg;
import core.stdc.string;
import core.stdc.stdio;
import core.stdc.stdlib;
import dmd.backend.cdef;

/**
Set MEM_DEBUG to `true` when compiling to enable extended debugging
features.
*/
enum MEM_DEBUG = false;

/**
Set MEM_NONE to `true` to compile out mem, i.e. have it all drop
 directly to calls to malloc, free, etc.
*/
enum MEM_NONE = false;

/**
Set MEM_NOMEMCOUNT to `true` to remove checks on the number of free's
matching the number of alloc's.
*/
enum MEM_NOMEMCOUNT = true;

/*
Features always enabled:
  o mem_init() is called at startup, and mem_term() at
    close, which checks to see that the number of alloc's is
    the same as the number of free's.
  o Behavior on out-of-memory conditions can be controlled
    via mem_setexception().

Extended debugging features:
  o Enabled by #define MEM_DEBUG 1 when compiling.
  o Check values are inserted before and after the alloc'ed data
    to detect pointer underruns and overruns.
  o Free'd pointers are checked against alloc'ed pointers.
  o Free'd storage is cleared to smoke out references to free'd data.
  o Realloc'd pointers are always changed, and the previous storage
    is cleared, to detect erroneous dependencies on the previous
    pointer.
  o The routine mem_checkptr() is provided to check an alloc'ed
    pointer.
*/

extern (C):
@nogc:
nothrow:

///Set behavior when mem runs out of memory.
enum Behavior
{
    /**
    Abort the program with the message
    'Fatal error: out of memory' sent to stdout. This is the default behavior.
    */
    ABORTMSG,

    /// Abort the program with no message.
    ABORT,

    /// Return NULL back to caller.
    RETNULL,

    /**
    Call application-specified function. fp must be supplied.

    fp  Optional function pointer. Supplied if (flag == MEM.CALLFP). This
    function returns MEM.XXXXX, indicating what mem should do next. The
    function could do things like swap data out to disk to free up more
    memory.

    fp could also return RETRY.

    The type of fp is `int (*handler)(void)``
    */
    CALLFP,

    /// Try again to allocate the space. Be careful not to go into an infinite loop.
    RETRY
}

/// Set behavior when mem runs out of memory.
private __gshared Behavior mem_behavior = Behavior.ABORTMSG;

/**
`true` if mem package is initialized.

Test this if you have other packages that depend on mem being initialized
*/
static if (MEM_NONE)
{
    private __gshared bool mem_inited = true;
}
else
{
    private __gshared bool mem_inited = false;
}

alias oom_fp_t = int function() @nogc nothrow;

/// out-of-memory handler
oom_fp_t oom_fp = null;

/// Behavior on out-of-memory conditions
void mem_setexception(Behavior flag, oom_fp_t f)
{
    mem_behavior = flag;
    oom_fp = f;

    static if (MEM_DEBUG)
    {
        assert(0 <= flag && flag <= Behavior.RETRY);
    }
}

/**
This is called when we're out of memory.
Returns:
     1:      try again to allocate the memory
     0:      give up and return null
*/
private int mem_exception()
{
    int behavior;

    behavior = mem_behavior;
    while (true)
    {
        switch (behavior)
        {
            case Behavior.ABORTMSG:
                fprintf(stderr, "Fatal error: out of memory\n");
                /* FALL-THROUGH */
                goto case;
            case Behavior.ABORT:
                exit(EXIT_FAILURE);
                /* NOTREACHED */
                break;
            case Behavior.CALLFP:
                assert(oom_fp);
                behavior = (*oom_fp)();
                break;
            case Behavior.RETNULL:
                return  0;
            case Behavior.RETRY:
                return  1;
            default:
                assert(0);
        }
    }

    assert(0);
}

/// # of allocs that haven't been free'd
private __gshared int mem_count;

/// # of sallocs that haven't been free'd
private __gshared int mem_scount;

static if (false)
{
    /**
    Initialize memory handler.
    Use:
        void mem_init(void);
    Output:
        mem_inited = 1
    */
    pragma(crt_constructor)
    void mem_init(void)
    {
        static if (MEM_NONE)
        {
            // ((void)0)
        }
        else static if (MEM_DEBUG)
        {

        }
        else
        {

        }
    }

    /**
    Terminate memory handler. Useful for checking for errors.
    Use:
        void mem_term(void);
    Output:
        mem_inited = 0
    */
    pragma(crt_destructor)
    void mem_term(void)
    {
        static if (MEM_NONE)
        {
            // ((void)0)
        }
        else static if (MEM_DEBUG)
        {

        }
        else
        {

        }
    }
}

/**
Allocate space for string, copy string into it, and
return pointer to the new string.
This routine doesn't really belong here, but it is used so often
that I gave up and put it here.
Use:
     char *mem_strdup(const char *s);
Returns:
     pointer to copied string if succussful.
     else returns NULL (if MEM_RETNULL)
*/
char *mem_strdup(const(char) *s)
{
    static if (MEM_NONE)
    {
        return strdup(s);
    }
    else static if (MEM_DEBUG)
    {
        return mem_strdup_debug(s, __FILE__, __LINE__);
    }
    else
    {
        if (s)
        {   size_t  len = strlen(s) + 1;
            char *p = cast(char *)mem_malloc(len);
            if (p)
                return cast(char *)memcpy(p, s, len);
        }
        return  null;
    }
}

/**
Function so we can have a pointer to function mem_free().
This is needed since mem_free is sometimes defined as a macro,
and then the preprocessor screws up.
The pointer to mem_free() is used frequently with the list package.
Use:
     void mem_freefp(void *ptr);
*/
void mem_freefp(void* ptr)
{
    static if (MEM_NONE)
    {
        free(ptr);
    }
    else static if (MEM_DEBUG)
    {
        mem_free(ptr);
    }
    else
    {
        mem_free(ptr);
    }
}

/**
Check for errors. This routine does a consistency check on the
storage allocator, looking for corrupted data. It should be called
when the application has CPU cycles to burn.
Use:
     void mem_check();
*/
void mem_check()
{
    static if (MEM_NONE)
    {
        // ((void)0)
    }
    else static if (MEM_DEBUG)
    {

    }
    else
    {

    }
}

/**
Check ptr to see if it is in the range of allocated data.
Cause assertion failure if it isn't.
*/
void mem_checkptr(void *ptr)
{
    static if (MEM_NONE)
    {
        // ((void)0)
    }
    else static if (MEM_DEBUG)
    {

    }
    else
    {

    }
}

/**
Allocate and return a pointer to numbytes of storage.
Use:
     void *mem_malloc(size_t numbytes);
Input:
     numbytes        Number of bytes to allocate
Returns:
     if (numbytes > 0)
             pointer to allocated data, NULL if out of memory
     else
             return NULL
*/
void *mem_malloc(size_t numbytes)
{
    static if (MEM_NONE)
    {
        return malloc(numbytes);
    }
    else static if (MEM_DEBUG)
    {
        //TODO: Need to get __FILE__ and __LINE__ sorted out
        return mem_malloc_debug(numbytes, __FILE__, __LINE__);
    }
    else
    {
        void *p;

        if (numbytes == 0)
            return  null;

        while (true)
        {
            p = malloc(numbytes);
            if (p  is  null)
            {
                if (mem_exception())
                    continue;
            }
            else
            {
                static if(!MEM_NOMEMCOUNT)
                {
                    mem_count++;
                }
            }
            break;
        }
        // printf("malloc(%d) = x%lx, mem_count = %d\n",numbytes,p,mem_count);
        return  p;
    }
}

/**
Allocate and return a pointer to numbytes of storage.
Use:
     void *mem_calloc(size_t numbytes); allocated memory is cleared
Input:
     numbytes        Number of bytes to allocate
Returns:
     if (numbytes > 0)
             pointer to allocated data, NULL if out of memory
     else
             return NULL
*/
void *mem_calloc(size_t numbytes)
{
    static if (MEM_NONE)
    {
        return calloc(numbytes, 1);
    }
    else static if (MEM_DEBUG)
    {
        return mem_calloc_debug(numbytes, __FILE__, __LINE__);
    }
    else
    {
        void *p;

        if (numbytes == 0)
            return  null;

        while (true)
        {
            p = calloc(numbytes, 1);
            if (p  is  null)
            {
                if (mem_exception())
                    continue;
            }
            else
            {
                static if(!MEM_NOMEMCOUNT)
                {
                    mem_count++;
                }
            }
            break;
        }
        // printf("calloc(%d) = x%lx, mem_count = %d\n",numbytes,p,mem_count);
        return  p;
    }
}

/**
Reallocate memory.
Use:
     void *mem_realloc(void *ptr,size_t numbytes);
*/
void *mem_realloc(void* ptr, size_t numbytes)
{
    static if (MEM_NONE)
    {
        return realloc(ptr, numbytes);
    }
    else static if (MEM_DEBUG)
    {
        return mem_realloc_debug(ptr, numbytes, __FILE__, __LINE__);
    }
    else
    {
        void *p;

        if (ptr is null)
            p = mem_malloc(numbytes);

        else  if (numbytes == 0)
        {
            mem_free(ptr);
            p = null;
        }
        else
        {
            do
                p = realloc(ptr, numbytes);
            while (p is null && mem_exception());
        }
        // printf("realloc(x%lx,%d) = x%lx, mem_count = %d\n",ptr,numbytes,p,mem_count);
        return  p;
    }
}

/**
Free memory allocated by mem_malloc(), mem_calloc() or mem_realloc().
Use:
     void mem_free(void* ptr);
*/
void mem_free(void* ptr)
{
    static if (MEM_NONE)
    {
        free(ptr);
    }
    else static if (MEM_DEBUG)
    {
        mem_free_debug(ptr, __FILE__, __LINE__);
    }
    else
    {
         /*printf("free(x%lx) mem_count=%d\n",ptr,mem_count);*/
        if (ptr !is null)
        {
            static if(!MEM_NOMEMCOUNT)
            {
                assert(mem_count != 0);
                mem_count--;
            }

            free(ptr);
        }
    }
}

static if (MEM_DEBUG)
{
    /// max # of bytes allocated
    private __gshared size_t  mem_maxalloc;

    /// current # of bytes allocated
    private __gshared size_t  mem_numalloc;

    /// value to detect underrun
    private  enum BEFOREVAL = 0x4F464542;

    /// value to detect overrun
    private enum AFTERVAL = 0x45544641;

    // The following should be selected to give maximum probability that
    // pointers loaded with these values will cause an obvious crash. On
    // Unix machines, a large value will cause a segment fault.
    // MALLOCVAL is the value to set malloc'd data to.
    static if(TARGET_WINDOS)
    {
        enum  BADVAL = 0xFF;
        enum  MALLOCVAL = 0xEE;
    }
    else
    {
        enum  BADVAL = 0x7A;
        enum  MALLOCVAL = 0xEE;
    }

    /**
    Create a list of all alloc'ed pointers, retaining info about where
    each alloc came from. This is a real memory and speed hog, but who
    cares when you've got obscure pointer bugs.
    */
    private struct mem_debug
    {
        /// next in list
        mem_debug *Mnext;

        /// previous value in list
        mem_debug *Mprev;

        /// filename of where allocated
        const(char) *Mfile;

        /// line number of where allocated
        int Mline = 11111;

        /// size of the allocation
        size_t Mnbytes;

        /// detect underrun of data
        uint Mbeforeval = BEFOREVAL;

        /// the data actually allocated
        char[1] data;  // #if !(__linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __DragonFly__ || __sun)
                       //     AFTERVAL
                       // #endif
    }

    private __gshared mem_debug mem_alloclist;

    // TODO: These aren't right
    /// Determine allocation size of a mem_debug
    private void  mem_debug_size(A)(A n)
    {
        ((mem_debug).sizeof - 1 + n + AFTERVAL.sizeof);
    }

    /// Convert from a void* to a mem_debug struct.
    private auto  mem_ptrtodl(A)(A p)
    {
        return cast(mem_debug*)(cast(char*)p - offsetof(mem_debug, data[0]));
    }

    /// Convert from a mem_debug struct to a mem_ptr.
    private void  mem_dltoptr(A)(A dl)
    {
        cast(void*)&(dl.data[0]);
    }

    /// Set new value of file,line
    private void mem_setnewfileline(void* ptr, const(char)* fil, int lin)
    {
        mem_debug *dl;

        dl = mem_ptrtodl(ptr);
        dl.Mfile = fil;
        dl.Mline = lin;
    }

    /// Print out struct mem_debug.
    private void mem_printdl(mem_debug* dl)
    {
        fprintf(stderr, "alloc'd from file '%s' line %d nbytes %d ptr %p\n",
            dl.Mfile, dl.Mline, dl.Mnbytes, cast(int)mem_dltoptr(dl));
    }

    /// Print out file and line number.
    private void mem_fillin(const(char)* fil, int lin)
    {
        fprintf(stderr, "File '%s' line %d\n", fil, lin);
        fflush(stderr);
    }

    /// Debug version of strdup()
    char *mem_strdup_debug (const(char)* s, const(char)* file, int line)
    {
        char *p;

        p = s
            ? cast(char *) mem_malloc_debug(cast(uint) strlen(s) + 1, file, line)
            : null;
        return  p ? strcpy(p,s) : p;
    }

    /// Debug version of mem_calloc()
    void *mem_calloc_debug (size_t n, const(char)* fil, int lin)
    {
        mem_debug *dl;

        do
            dl = cast(mem_debug *) calloc(mem_debug_size(n),1);
        while (dl is null && mem_exception());

        if (dl is null)
            return null;

        dl.Mfile = fil;
        dl.Mline = lin;
        dl.Mnbytes = n;
        dl.Mbeforeval = BEFOREVAL;
        *cast(int *) &(dl.data[n]) = AFTERVAL;

        // Add dl to start of allocation list
        dl.Mnext = mem_alloclist.Mnext;
        dl.Mprev = &mem_alloclist;
        mem_alloclist.Mnext = dl;
        if (dl.Mnext !is  null)
            dl.Mnext.Mprev = dl;

        mem_count++;
        mem_numalloc += n;
        if (mem_numalloc > mem_maxalloc)
            mem_maxalloc = mem_numalloc;
        return  mem_dltoptr(dl);
    }

    /// Debug version of mem_malloc()
    void *mem_malloc_debug (size_t n, const(char)* fil, int lin)
    {
        void *p;

        p = mem_calloc_debug(n, fil, lin);

        if (p)
            memset(p, MALLOCVAL, n);

        return  p;
    }

    /// Debug version of mem_realloc()
    void *mem_realloc_debug (void* ptr, size_t u, const(char)* fil, int lin)
    {
        void *p;
        mem_debug *dl;

        if (n == 0)
        {
            mem_free_debug(oldp,fil,lin);
            p = null;
        }
        else if (oldp  is  null)
            p = mem_malloc_debug(n,fil,lin);
        else
        {
            p = mem_malloc_debug(n,fil,lin);
            if (p !is  null)
            {
                dl = mem_ptrtodl(oldp);
                if (dl.Mnbytes < n)
                    n = dl.Mnbytes;
                memcpy(p,oldp,n);
                mem_free_debug(oldp,fil,lin);
            }
        }
        return p;
    }

    /// Debug version of mem_free()
    void mem_free_debug (void* ptr, const(char)* fil, int lin)
    {
        mem_debug *dl;
        int  error;

        if (ptr  is  null)
                return;
        if (mem_count <= 0)
        {
            fprintf(stderr, "More frees than allocs at ");
            goto  err;
        }
        dl = mem_ptrtodl(ptr);
        if (dl.Mbeforeval != BEFOREVAL)
        {
            fprintf(stderr, "Pointer x%lx underrun\n", cast(int)ptr);
            fprintf(stderr, "'%s'(%d)\n",fil,lin);
            goto  err2;
        }

        error = (*cast(int *) &dl.data[dl.Mnbytes] != AFTERVAL);
        if (error)
        {
            fprintf(stderr, "Pointer x%lx overrun\n", cast(int)ptr);
            goto  err2;
        }
        mem_numalloc -= dl.Mnbytes;
        if (mem_numalloc < 0)
        {
            fprintf(stderr, "error: mem_numalloc = %ld, dl->Mnbytes = %d\n",
            mem_numalloc,dl.Mnbytes);
            goto  err2;
        }

        // Remove dl from linked list
        if (dl.Mprev)
            dl.Mprev.Mnext = dl.Mnext;
        if (dl.Mnext)
            dl.Mnext.Mprev = dl.Mprev;

        // Stomp on the freed storage to help detect references
        // after the storage was freed.
        memset(cast(void *) dl,BADVAL,(*dl).sizeof + dl.Mnbytes);
        mem_count--;

        free(cast(void *) dl);
        return;

    err2:
        mem_printdl(dl);

    err:
        fprintf(stderr, "free'd from ");
        mem_fillin(fil, lin);
        assert(0);
        /* NOTREACHED */
    }

    private void mem_checkdl(mem_debug* dl)
    {
        void *p;

        p = mem_dltoptr(dl);
        if (dl.Mbeforeval != BEFOREVAL)
        {
            fprintf(stderr, "Pointer x%lx underrun\n", cast(int)p);
            goto err2;
        }

        error = *cast(int *) &dl.data[dl.Mnbytes] != AFTERVAL;

        if (error)
        {
            fprintf(stderr, "Pointer x%lx overrun\n", cast(int)p);
            goto err2;
        }
        return;

    err2:
        mem_printdl(dl);
        assert(0);
    }

    private void mem_check()
    {
        mem_debug *dl;

        for (dl = mem_alloclist.Mnext; dl !is  null; dl = dl.Mnext)
            mem_checkdl(dl);
    }

    private void mem_checkptr(void* p)
    {
        mem_debug *dl;

        for (dl = mem_alloclist.Mnext; dl !is  null; dl = dl.Mnext)
        {
            if (p >= cast(void *) &(dl.data[0]) &&
                p < cast(void *)(cast(char *)dl + (mem_debug).sizeof-1 + dl.Mnbytes))
                goto  L1;
        }
        assert(0);

    L1:
        mem_checkdl(dl);
    }
}

/***************************/
/* This is our low-rent fast storage allocator  */

private __gshared char *mem_heap;
private __gshared size_t mem_heapleft;

/***************************/

/* #if 0 && __SC__ && __INTSIZE == 4 && __I86__ && !_DEBUG_TRACE && _WIN32 && (SCC || SCPP || JAVA)

__declspec(naked) void *mem_fmalloc(size_t numbytes)
{
    __asm
    {
        mov     EDX,4[ESP]
        mov     EAX,mem_heap
        add     EDX,3
        mov     ECX,mem_heapleft
        and     EDX,~3
        je      L5A
        cmp     EDX,ECX
        ja      L2D
        sub     ECX,EDX
        add     EDX,EAX
        mov     mem_heapleft,ECX
        mov     mem_heap,EDX
        ret     4

L2D:    push    EBX
        mov     EBX,EDX
//      add     EDX,03FFFh
//      and     EDX,~03FFFh
        add     EDX,03C00h
        mov     mem_heapleft,EDX
L3D:    push    mem_heapleft
        call    mem_malloc
        test    EAX,EAX
        mov     mem_heap,EAX
        jne     L18
        call    mem_exception
        test    EAX,EAX
        jne     L3D
        pop     EBX
L5A:    xor     EAX,EAX
        ret     4

L18:    add     mem_heap,EBX
        sub     mem_heapleft,EBX
        pop     EBX
        ret     4
    }
}

#else */

// The mem_fxxx() functions are for allocating memory that will persist
// until program termination. The trick is that if the memory is never
// free'd, we can do a very fast allocation. If MEM_DEBUG is on, they
// act just like the regular mem functions, so it can be debugged.


// GCC and Clang assume some types, notably elem (see DMD issue 6215),
// to be 16-byte aligned. Because we do not have any type information
// available here, we have to 16 byte-align everything.
version(GNU)
{
    version = Align16Byte;
}
version(LDC)
{
    version = Align16Byte;
}

void *mem_fmalloc(size_t numbytes)
{
    static if (MEM_NONE)
    {
        return malloc(numbytes);
    }
    else static if (MEM_DEBUG)
    {
        return mem_malloc(numbytes);
    }
    else
    {
        void *p;

        //printf("fmalloc(%d)\n",numbytes);

        version(Align16Byte)
        {
            numbytes = (numbytes + 0xF) & ~0xF;
        }
        else
        {
            if (size_t.sizeof == 2)
                numbytes = (numbytes + 1) & ~1;         // word align
            else
                numbytes = (numbytes + 3) & ~3;         // dword align
        }

        // This ugly flow-of-control is so that the most common case
        // drops straight through.

        if (!numbytes)
            return  null;

        if (numbytes <= mem_heapleft)
        {
L2:
            p = cast(void *)mem_heap;
            mem_heap += numbytes;
            mem_heapleft -= numbytes;
            return  p;
        }

        static if (true)
        {
            mem_heapleft = numbytes + 0x3C00;
            if (mem_heapleft >= 16372)
                mem_heapleft = numbytes;
        }
        else static if(_WIN32)
        {
            mem_heapleft = (numbytes + 0x3FFF) & ~0x3FFF;   // round to next boundary
        }
        else
        {
            mem_heapleft = 0x3F00;
            assert(numbytes <= mem_heapleft);
        }

L1:
        mem_heap = cast(char *)malloc(mem_heapleft);
        if (!mem_heap)
        {
            if (mem_exception())
                goto L1;
            return null;
        }
        goto L2;
    }
}

void *mem_fcalloc(size_t numbytes)
{
    static if (MEM_NONE)
    {
        return calloc(numbytes, 1);
    }
    else static if (MEM_DEBUG)
    {
        return mem_calloc(numbytes);
    }
    else
    {
        void *p;

        p = mem_fmalloc(numbytes);
        return  p ? memset(p,0,numbytes) : p;
    }
}

void mem_ffree(void* ptr)
{
    static if (MEM_NONE)
    {
        // ((void)0)
    }
    else static if (MEM_DEBUG)
    {
        mem_free(ptr);
    }
    else
    {
        // ((void)0)
    }
}

char *mem_fstrdup(const(char)* s)
{
    static if (MEM_NONE)
    {
        return strdup(s);
    }
    else static if (MEM_DEBUG)
    {
        return mem_strdup(s);
    }
    else
    {
        if (s)
        {
            size_t  len = strlen(s) + 1;
            char *p = cast(char *) mem_fmalloc(len);
            if (p)
                return cast(char *)memcpy(p,s,len);
        }
        return  null;
    }
}
