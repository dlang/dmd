/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/mem.d, backend/mem.d)
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/mem.d
 */

 /*
 * Memory management routines.
 *
 * Compiling:
 *
 *      #define MEM_DEBUG 1 when compiling to enable extended debugging
 *      features.
 *
 *      #define MEM_NONE 1 to compile out mem, i.e. have it all drop
 *      directly to calls to malloc, free, etc.
 *
 *      #define MEM_NOMEMCOUNT 1 to remove checks on the number of free's
 *      matching the number of alloc's.
 *
 * Features always enabled:
 *
 *      o mem_init() is called at startup, and mem_term() at
 *        close, which checks to see that the number of alloc's is
 *        the same as the number of free's.
 *      o Behavior on out-of-memory conditions can be controlled
 *        via mem_setexception().
 *
 * Extended debugging features:
 *
 *      o Enabled by #define MEM_DEBUG 1 when compiling.
 *      o Check values are inserted before and after the alloc'ed data
 *        to detect pointer underruns and overruns.
 *      o Free'd pointers are checked against alloc'ed pointers.
 *      o Free'd storage is cleared to smoke out references to free'd data.
 *      o Realloc'd pointers are always changed, and the previous storage
 *        is cleared, to detect erroneous dependencies on the previous
 *        pointer.
 *      o The routine mem_checkptr() is provided to check an alloc'ed
 *        pointer.
 */

module dmd.backend.mem;

import core.stdc.stdarg;
import core.stdc.string;
import core.stdc.stdio;
import core.stdc.stdlib;
import dmd.backend.cdef;

extern (C):
nothrow:
@nogc:

char *mem_strdup(const(char) *);
void *mem_malloc(size_t);
void *mem_calloc(size_t);
void *mem_realloc(void *,size_t);
void mem_free(void *);
void mem_init();
void mem_term();

extern (C++)
{
    void mem_free_cpp(void *);
    alias mem_freefp = mem_free_cpp;
}

version (MEM_DEBUG)
{
    alias mem_fstrdup = mem_strdup;
    alias mem_fcalloc = mem_calloc;
    alias mem_fmalloc = mem_malloc;
    alias mem_ffree   = mem_free;
}
else
{
    char *mem_fstrdup(const(char) *);
    void *mem_fcalloc(size_t);
    void *mem_fmalloc(size_t);
    void mem_ffree(void *) { }
}

version (MEM_NONE)
{
    /**
    Test this if you have other packages
    that depend on mem being initialized

    != 0 if initialized
    */
    private __gshared int mem_inited = 1;
}
else
{
    /**
    Test this if you have other packages
    that depend on mem being initialized

    != 0 if initialized
    */
    private __gshared int mem_inited = 0;

    /// # of allocs that haven't been free'd
    private __gshared int mem_count;

    /// # of sallocs that haven't been free'd
    private __gshared int mem_scount;

    /// Set behavior when mem runs out of memory.
    enum MEM_E : int
    {
        /**
        Abort the program with the message
        'Fatal error: out of memory' sent to stdout. This is the default behavior.
        */
        MEM_ABORTMSG,

        /// Abort the program with no message.
        MEM_ABORT,

        /// Return NULL back to caller.
        MEM_RETNULL,

        /**
        Call application-specified function. fp must be supplied.

        fp  Optional function pointer. Supplied if (flag == MEM.CALLFP). This
        function returns MEM.XXXXX, indicating what mem should do next. The
        function could do things like swap data out to disk to free up more
        memory.

        fp could also return RETRY.

        The type of fp is `int (*handler)(void)``
        */
        MEM_CALLFP,

        /// Try again to allocate the space. Be careful not to go into an infinite loop.
        MEM_RETRY
    }

    /// Set behavior when mem runs out of memory.
    private __gshared MEM_E mem_behavior = MEM_E.MEM_ABORTMSG;

    alias oom_fp_t = int function() @nogc nothrow;

    /// out-of-memory handler
    private __gshared oom_fp_t oom_fp = null;

    /// Behavior on out-of-memory conditions
    void mem_setexception(MEM_E flag, oom_fp_t f)
    {
        mem_behavior = flag;
        oom_fp = f;

        version (MEM_DEBUG)
        {
            assert(0 <= flag && flag <= MEM_E.MEM_RETRY);
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
        MEM_E behavior;

        behavior = mem_behavior;
        while (true)
        {
            switch (behavior)
            {
                case MEM_E.MEM_ABORTMSG:
                    fprintf(stderr, "Fatal error: out of memory\n");
                    /* FALL-THROUGH */
                    goto case;
                case MEM_E.MEM_ABORT:
                    exit(EXIT_FAILURE);
                    /* NOTREACHED */
                    break;
                case MEM_E.MEM_CALLFP:
                    assert(oom_fp);
                    behavior = cast(MEM_E)(*oom_fp)();
                    break;
                case MEM_E.MEM_RETNULL:
                    return  0;
                case MEM_E.MEM_RETRY:
                    return  1;
                default:
                    assert(0);
            }
        }

        assert(0);
    }
}
