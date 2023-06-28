/**
 * Contains support code for code profiling.
 *
 * Copyright: Copyright Digital Mars 1995 - 2017.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly, the LDC team
 * Source: $(DRUNTIMESRC rt/_trace.d)
 */

module rt.trace;

import core.demangle;
import core.stdc.ctype;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

version (CRuntime_Microsoft)
    private alias core.stdc.stdlib._strtoui64 strtoull;

shared static this ()
{
    enum DefaultLog = "trace.log";
    enum DefaultDef = "trace.def";

    trace_logfilename = strdup(DefaultLog.ptr)[0 .. DefaultLog.length + 1];
    trace_deffilename = strdup(DefaultDef.ptr)[0 .. DefaultDef.length + 1];
}

/**
 * Set the file path for profile reports (`-profile`)
 *
 * This function is a public API, exposed in `core.runtime`.
 *
 * Since we are calling C functions under the hood,
 * and we might need to open and close files during the
 * runtime tear-down we copy the parameter via malloc
 * to ensure NUL-termination.
 *
 * Params:
 *   name = Path to the output file. Empty means stdout.
 */
extern(C) void trace_setlogfilename(string name)
{
    updateFileName(trace_logfilename, name);
}

/**
 * Set the file path for the optimized profile linker DEF file (`-profile`)
 *
 * This function is a public API, exposed in `core.runtime`.
 *
 * Since we are calling C functions under the hood,
 * and we might need to open and close files during the
 * runtime tear-down we copy the parameter via malloc
 * to ensure NUL-termination.
 *
 * Params:
 *   name = Path to the output file. Empty means stdout.
 */
extern(C) void trace_setdeffilename(string name)
{
    updateFileName(trace_deffilename, name);
}

private:

// Code shared by both `trace_setXXXfilename`
void updateFileName(ref char[] filename, string name)
{
    if (!name.length)
    {
        free(filename.ptr);
        filename = null;
    }
    else if (auto newPtr = cast(char*)realloc(filename.ptr, name.length + 1))
    {
        filename = newPtr[0 .. name.length + 1];
        filename[0 .. $ - 1] = name[];
        filename[$ - 1] = 0;
    }
    else
        assert(0, "Memory allocation failed");
}

alias long timer_t;

/////////////////////////////////////
//

struct SymPair
{
    SymPair* next;
    Symbol* sym;        // function that is called
    ulong count;        // number of times sym is called
}

/////////////////////////////////////
// A Symbol for each function name.

struct Symbol
{
        Symbol* Sl, Sr;         // left, right children
        SymPair* Sfanin;        // list of calling functions
        SymPair* Sfanout;       // list of called functions
        timer_t totaltime;      // aggregate time
        timer_t functime;       // time excluding subfunction calls
        ubyte Sflags;           // SFxxxx
        uint recursion;         // call recursion level
        const(char)[] Sident;   // name of symbol
}

enum ubyte SFvisited = 1;      // visited


//////////////////////////////////
// Build a linked list of these.

struct Stack
{
    Stack* prev;
    Symbol* sym;
    timer_t starttime;          // time when function was entered
    timer_t ohd;                // overhead of all the bookkeeping code
    timer_t subtime;            // time used by all subfunctions
}

Symbol* root;               // root of symbol table
bool trace_inited;

Stack* stack_freelist;
Stack* trace_tos;           // top of stack

__gshared
{
    Symbol* groot;              // merged symbol table
    int gtrace_inited;          // !=0 if initialized

    timer_t trace_ohd;

    // Those strings include the `\0` in their slice as they're used with fopen
    char[] trace_logfilename;
    char[] trace_deffilename;
}

////////////////////////////////////////
// Output optimal function link order.

private void trace_order(FILE* fpdef, Symbol *s)
{
    while (s)
    {
        trace_place(fpdef, s, 0);
        if (s.Sl)
            trace_order(fpdef, s.Sl);
        s = s.Sr;
    }
}

//////////////////////////////////////////////
//

private Stack* stack_push()
{
    Stack *s;

    if (stack_freelist)
    {
        s = stack_freelist;
        stack_freelist = s.prev;
    }
    else
    {
        s = cast(Stack *)trace_malloc(Stack.sizeof);
    }
    s.prev = trace_tos;
    trace_tos = s;
    return s;
}

//////////////////////////////////////////////
//

private void stack_free(Stack *s)
{
    s.prev = stack_freelist;
    stack_freelist = s;
}

//////////////////////////////////////
// Qsort() comparison routine for array of pointers to SymPair's.

extern(C) int sympair_cmp(scope const void* e1, scope const void* e2) nothrow @nogc
{
    auto count1 = (*cast(SymPair**)e1).count;
    auto count2 = (*cast(SymPair**)e2).count;
    return (count1 > count2) - (count1 < count2);
}

//////////////////////////////////////
// Place symbol s, and then place any fan ins or fan outs with
// counts greater than count.

private void trace_place(FILE* fpdef, Symbol* s, ulong count)
{
    if (!(s.Sflags & SFvisited))
    {
        //printf("\t%.*s\t%llu\n", s.Sident.length, s.Sident.ptr, count);
        fprintf(fpdef,"\t%.*s\n", cast(int) s.Sident.length, s.Sident.ptr);
        s.Sflags |= SFvisited;

        // Compute number of items in array
        size_t num = 0;
        for (auto sp = s.Sfanin; sp; sp = sp.next)
            num++;
        for (auto sp = s.Sfanout; sp; sp = sp.next)
            num++;
        if (!num)
            return;

        // Allocate and fill array
        auto base = cast(SymPair**)trace_malloc(SymPair.sizeof * num);
        size_t u = 0;
        for (auto sp = s.Sfanin; sp; sp = sp.next)
            base[u++] = sp;
        for (auto sp = s.Sfanout; sp; sp = sp.next)
            base[u++] = sp;
        assert(u == num);

        // Sort array
        qsort(base, num, (SymPair *).sizeof, &sympair_cmp);

        //for (u = 0; u < num; u++)
            //printf("\t\t%.*s\t%llu\n", base[u].sym.Sident.length, base[u].sym.Sident.ptr, base[u].count);

        // Place symbols
        for (u = 0; u < num; u++)
        {
            if (base[u].count >= count)
            {
                auto u2 = (u + 1 < num) ? u + 1 : u;
                auto c2 = base[u2].count;
                if (c2 < count)
                    c2 = count;
                trace_place(fpdef, base[u].sym,c2);
            }
            else
                break;
        }

        // Clean up
        trace_free(base);
    }
}

///////////////////////////////////
// Report results.
// Also compute and return number of symbols.

private size_t trace_report(FILE* fplog, Symbol* s)
{
    //printf("trace_report()\n");
    size_t nsymbols;
    while (s)
    {
        ++nsymbols;
        if (s.Sl)
            nsymbols += trace_report(fplog, s.Sl);
        fprintf(fplog,"------------------\n");
        ulong count = 0;
        for (auto sp = s.Sfanin; sp; sp = sp.next)
        {
            fprintf(fplog,"\t%5llu\t%.*s\n", sp.count, cast(int) sp.sym.Sident.length, sp.sym.Sident.ptr);
            count += sp.count;
        }
        fprintf(fplog,"%.*s\t%llu\t%lld\t%lld\n", cast(int) s.Sident.length, s.Sident.ptr, count, s.totaltime, s.functime);
        for (auto sp = s.Sfanout; sp; sp = sp.next)
        {
            fprintf(fplog,"\t%5llu\t%.*s\n", sp.count, cast(int) sp.sym.Sident.length, sp.sym.Sident.ptr);
        }
        s = s.Sr;
    }
    return nsymbols;
}

////////////////////////////////////
// Allocate and fill array of symbols.

private void trace_array(Symbol*[] psymbols, Symbol *s, ref uint u)
{
    while (s)
    {
        psymbols[u++] = s;
        trace_array(psymbols, s.Sl, u);
        s = s.Sr;
    }
}


//////////////////////////////////////
// Qsort() comparison routine for array of pointers to Symbol's.

extern(C) int symbol_cmp(scope const void* e1, scope const void* e2) nothrow @nogc
{
    auto ps1 = cast(Symbol **)e1;
    auto ps2 = cast(Symbol **)e2;

    auto diff = (*ps2).functime - (*ps1).functime;
    return (diff == 0) ? 0 : ((diff > 0) ? 1 : -1);
}


///////////////////////////////////
// Report function timings

private void trace_times(FILE* fplog, Symbol*[] psymbols)
{
    // Sort array
    qsort(psymbols.ptr, psymbols.length, (Symbol *).sizeof, &symbol_cmp);

    // Print array header
    timer_t time_scale;
    static if (is(typeof(&QueryPerformanceFrequency)))
    {
        timer_t freq;
        QueryPerformanceFrequency(&freq);
        time_scale = freq / 1_000_000;
        fprintf(fplog,"\n======== Timer Is %lld Ticks/Sec, Times are in Microsecs ========\n\n",freq);
    }
    else
    {
        // The exact frequency is unknown (and may vary), so do the reporting in Mega Ticks,
        // which corresponds to 1 microsecond on a 1GHz clock.
        time_scale = 1_000_000;
        fprintf(fplog,"\n======== Timer frequency unknown, Times are in Megaticks ========\n\n");
    }
    fprintf(fplog,"  Num          Tree        Func        Per\n");
    fprintf(fplog,"  Calls        Time        Time        Call\n\n");

    // Print array
    foreach (s; psymbols)
    {
        timer_t tl,tr;
        timer_t fl,fr;
        timer_t pl,pr;
        char[8192] buf = void;
        SymPair* sp;
        ulong calls;
        char[] id;

        calls = 0;
        id = demangle(s.Sident, buf);
        for (sp = s.Sfanin; sp; sp = sp.next)
            calls += sp.count;
        if (calls == 0)
            calls = 1;

        tl = s.totaltime / time_scale;
        fl = s.functime / time_scale;
        pl = s.functime / calls / time_scale;

        fprintf(fplog,"%7llu%12lld%12lld%12lld     %.*s\n",
                      calls, tl, fl, pl, cast(int) id.length, id.ptr);
    }
}


///////////////////////////////////
// Initialize.

private void trace_init()
{
    synchronized        // protects gtrace_inited
    {
        if (!gtrace_inited)
        {
            gtrace_inited = 1;

            {   // See if we can determine the overhead.
                timer_t starttime;
                timer_t endtime;

                auto st = trace_tos;
                trace_tos = null;
                QueryPerformanceCounter(&starttime);
                uint u;
                for (u = 0; u < 100; u++)
                {
                    _c_trace_pro(0,null);
                    _c_trace_epi();
                }
                QueryPerformanceCounter(&endtime);
                trace_ohd = (endtime - starttime) / u;
                //printf("trace_ohd = %lld\n",trace_ohd);
                if (trace_ohd > 0)
                    trace_ohd--;            // round down
                trace_tos = st;
            }
        }
    }
}

/////////////////////////////////
// Terminate.

static ~this()
{
    // Free remainder of the thread local stack
    while (trace_tos)
    {
        auto n = trace_tos.prev;
        stack_free(trace_tos);
        trace_tos = n;
    }

    // And free the thread local stack's memory
    while (stack_freelist)
    {
        auto n = stack_freelist.prev;
        stack_free(stack_freelist);
        stack_freelist = n;
    }

    synchronized        // protects groot
    {
        // Merge thread local root into global groot

        if (!groot)
        {
            groot = root;       // that was easy
            root = null;
        }
        else
        {
            void mergeSymbol(Symbol** proot, const(Symbol)* s)
            {
                while (s)
                {
                    auto gs = trace_addsym(proot, s.Sident);
                    gs.totaltime += s.totaltime;
                    gs.functime  += s.functime;

                    static void mergeFan(Symbol** proot, SymPair** pgf, const(SymPair)* sf)
                    {
                        for (; sf; sf = sf.next)
                        {
                            auto sym = trace_addsym(proot, sf.sym.Sident);
                            for (auto gf = *pgf; 1; gf = gf.next)
                            {
                                if (!gf)
                                {
                                    auto sp = cast(SymPair *)trace_malloc(SymPair.sizeof);
                                    sp.next = *pgf;
                                    *pgf = sp;
                                    sp.sym = sym;
                                    sp.count = sf.count;
                                    break;
                                }
                                if (gf.sym == sym)
                                {
                                    gf.count += sf.count;
                                    break;
                                }
                            }
                        }
                    }

                    mergeFan(proot, &gs.Sfanin, s.Sfanin);
                    mergeFan(proot, &gs.Sfanout, s.Sfanout);

                    mergeSymbol(proot, s.Sl);
                    s = s.Sr;
                }
            }

            mergeSymbol(&groot, root);
        }
    }

    // Free the memory for the thread local symbol table (root)
    static void freeSymbol(Symbol* s)
    {
        while (s)
        {
            freeSymbol(s.Sl);
            auto next = s.Sr;

            static void freeSymPair(SymPair* sp)
            {
                while (sp)
                {
                    auto spnext = sp.next;
                    trace_free(sp);
                    sp = spnext;
                }
            }

            freeSymPair(s.Sfanin);
            freeSymPair(s.Sfanout);
            trace_free(s);
            s = next;
        }
    }

    freeSymbol(root);
    root = null;
}

shared static ~this()
{
    //printf("shared static ~this() groot = %p\n", groot);
    if (gtrace_inited == 1)
    {
        gtrace_inited = 2;

        // Merge in data from any existing file
        trace_merge(&groot);

        // Report results
        FILE* fplog = trace_logfilename.length == 0 ? stdout :
            fopen(trace_logfilename.ptr, "w");
        if (fplog)
        {
            auto nsymbols = trace_report(fplog, groot);

            auto p = cast(Symbol **)trace_malloc((Symbol *).sizeof * nsymbols);
            auto psymbols = p[0 .. nsymbols];

            uint u;
            trace_array(psymbols, groot, u);
            trace_times(fplog, psymbols);
            fclose(fplog);

            trace_free(psymbols.ptr);
            psymbols = null;
        }
        else
            fprintf(stderr, "cannot write '%s'", trace_logfilename.ptr);

        // Output function link order
        FILE* fpdef = trace_deffilename.length == 0 ? stdout :
            fopen(trace_deffilename.ptr, "w");
        if (fpdef)
        {
            fprintf(fpdef,"\nFUNCTIONS\n");
            trace_order(fpdef, groot);
            fclose(fpdef);
        }
        else
            fprintf(stderr, "cannot write '%s'", trace_deffilename.ptr);
    }
}

/////////////////////////////////
// Our storage allocator.

private void *trace_malloc(size_t nbytes)
{
    auto p = malloc(nbytes);
    if (!p)
        exit(EXIT_FAILURE);
    return p;
}

private void trace_free(void *p)
{
    free(p);
}

//////////////////////////////////////////////
//

private Symbol* trace_addsym(Symbol** proot, const(char)[] id)
{
    //printf("trace_addsym('%s',%d)\n",p,len);
    auto parent = proot;
    auto rover = *parent;
    while (rover !is null)               // while we haven't run out of tree
    {
        immutable len = id.length <= rover.Sident.length ? id.length : rover.Sident.length;
        int cmp = memcmp(id.ptr, rover.Sident.ptr, len);
        if (!cmp)
            cmp = id.length < rover.Sident.length ? -1 : (id.length > rover.Sident.length);
        if (cmp == 0)
        {
            return rover;
        }
        parent = (cmp < 0) ?            /* if we go down left side      */
            &(rover.Sl) :               /* then get left child          */
            &(rover.Sr);                /* else get right child         */
        rover = *parent;                /* get child                    */
    }
    /* not in table, so insert into table       */
    auto s = cast(Symbol *)trace_malloc(Symbol.sizeof);
    memset(s,0,Symbol.sizeof);
    s.Sident = id;
    *parent = s;                        // link new symbol into tree
    return s;
}

/***********************************
 * Add symbol s with count to SymPair list.
 */

private void trace_sympair_add(SymPair** psp, Symbol* s, ulong count)
{
    SymPair* sp;

    for (; 1; psp = &sp.next)
    {
        sp = *psp;
        if (!sp)
        {
            sp = cast(SymPair *)trace_malloc(SymPair.sizeof);
            sp.sym = s;
            sp.count = 0;
            sp.next = null;
            *psp = sp;
            break;
        }
        else if (sp.sym == s)
        {
            break;
        }
    }
    sp.count += count;
}

//////////////////////////////////////////////
// This one is called by DMD

private extern(C) void trace_pro(char[] id)
{
    //printf("trace_pro(ptr = %p, length = %lld)\n", id.ptr, id.length);
    //printf("trace_pro(id = '%.*s')\n", id.length, id.ptr);

    if (!trace_inited)
    {
        trace_inited = true;
        trace_init();                   // initialize package
    }

    timer_t starttime;
    QueryPerformanceCounter(&starttime);
    if (id.length == 0)
        return;
    auto tos = stack_push();
    auto s = trace_addsym(&root, id);
    tos.sym = s;
    if (tos.prev)
    {
        // Accumulate Sfanout and Sfanin
        auto prev = tos.prev.sym;
        trace_sympair_add(&prev.Sfanout,s,1);
        trace_sympair_add(&s.Sfanin,prev,1);
    }
    timer_t t;
    QueryPerformanceCounter(&t);
    tos.starttime = starttime;
    tos.ohd = trace_ohd + t - starttime;
    tos.subtime = 0;
    ++s.recursion;
    //printf("tos.ohd=%lld, trace_ohd=%lld + t=%lld - starttime=%lld\n",
    //  tos.ohd,trace_ohd,t,starttime);
}

// Called by some old versions of DMD
extern(C) void _c_trace_pro(size_t idlen, char* idptr)
{
    char[] id = idptr[0 .. idlen];
    trace_pro(id);
}

/////////////////////////////////////////
// Called by DMD generated code

extern(C) void _c_trace_epi()
{
    //printf("_c_trace_epi()\n");
    auto tos = trace_tos;
    if (tos)
    {
        timer_t endtime;
        QueryPerformanceCounter(&endtime);
        auto starttime = tos.starttime;
        auto totaltime = endtime - starttime - tos.ohd;
        if (totaltime < 0)
        {   //printf("endtime=%lld - starttime=%lld - tos.ohd=%lld < 0\n",
            //  endtime,starttime,tos.ohd);
            totaltime = 0;              // round off error, just make it 0
        }

        // totaltime is time spent in this function + all time spent in
        // subfunctions - bookkeeping overhead.
        --tos.sym.recursion;
        if (tos.sym.recursion == 0)
            tos.sym.totaltime += totaltime;

        //if (totaltime < tos.subtime)
        //printf("totaltime=%lld < tos.subtime=%lld\n",totaltime,tos.subtime);
        tos.sym.functime  += totaltime - tos.subtime;
        auto ohd = tos.ohd;
        auto n = tos.prev;
        stack_free(tos);
        trace_tos = n;
        if (n)
        {
            timer_t t;
            QueryPerformanceCounter(&t);
            n.ohd += ohd + t - endtime;
            n.subtime += totaltime;
            //printf("n.ohd = %lld\n",n.ohd);
        }
    }
}


////////////////////////// FILE INTERFACE /////////////////////////

/////////////////////////////////////
// Read line from file fp.
// Returns:
//      trace_malloc'd line buffer
//      null if end of file

char[] trace_readline(FILE* fp)
{
    char[] buf;
    // Last character used in `buf`
    size_t idx;
    // Used to break out of the do .. while
    int currentChar = EOF;

    //printf("trace_readline(%p)\n", fp);
    do
    {
        if (buf.length <= idx)
        {
            const size_t newLength = buf.length + 80;
            if (auto newPtr = cast(char*)realloc(buf.ptr, newLength))
                buf = newPtr[0 .. newLength];
            else
                assert(0, "Memory allocation failed");
        }
        currentChar = fgetc(fp);
        buf[idx++] = cast(char)currentChar;
    } while (currentChar != EOF && currentChar != '\n');

    // Encountered '\n' or EOF immediately
    // The calling code makes a distinction between EOF and '\n'
    if (idx == 1 && currentChar == EOF)
    {
        trace_free(buf.ptr);
        return null;
    }
    buf[idx - 1] = 0;
    return buf[0 .. idx];
}

//////////////////////////////////////
// Skip space

private char *skipspace(char *p)
{
    while (isspace(*p))
        p++;
    return p;
}

////////////////////////////////////////////////////////
// Merge in profiling data from existing file.

private void trace_merge(Symbol** proot)
{
    // We're outputting to stdout
    if (!trace_logfilename.length)
        return;

    FILE* fp = fopen(trace_logfilename.ptr, "r");
    if (fp is null)
        return;
    scope(exit) fclose(fp);

    char* buf = null;
    SymPair* sfanin = null;
    auto psp = &sfanin;
    char *p;
    ulong count;
    Symbol *s;

    while (1)
    {
        trace_free(buf);
        buf = trace_readline(fp).ptr;
        if (!buf)
            break;
        switch (*buf)
        {
        case '=':               // ignore rest of file
            trace_free(buf);
            return;
        case ' ':
        case '\t':              // fan in or fan out line
            count = strtoul(buf,&p,10);
            if (p == buf)       // if invalid conversion
                continue;
            p = skipspace(p);
            if (!*p)
                continue;
            s = trace_addsym(proot, p[0 .. strlen(p)]);
            trace_sympair_add(psp,s,count);
            break;
        default:
            if (!isalpha(*buf))
            {
                if (!sfanin)
                    psp = &sfanin;
                continue;       // regard unrecognized line as separator
            }
            goto case;
        case '?':
        case '_':
        case '$':
        case '@':
            p = buf;
            while (isgraph(*p))
                p++;
            *p = 0;
            //printf("trace_addsym('%s')\n",buf);
            s = trace_addsym(proot, buf[0 .. strlen(buf)]);
            if (s.Sfanin)
            {
                SymPair *sp;

                for (; sfanin; sfanin = sp)
                {
                    trace_sympair_add(&s.Sfanin,sfanin.sym,sfanin.count);
                    sp = sfanin.next;
                    trace_free(sfanin);
                }
            }
            else
                s.Sfanin = sfanin;

            sfanin = null;
            psp = &s.Sfanout;

            {
                p++;
                count = strtoul(p,&p,10);
                timer_t t = cast(long)strtoull(p,&p,10);
                s.totaltime += t;
                t = cast(long)strtoull(p,&p,10);
                s.functime += t;
            }
            break;
        }
    }
}

////////////////////////// COMPILER INTERFACE /////////////////////

version (Windows)
{
    extern (Windows)
    {
        export int QueryPerformanceCounter(timer_t *);
        export int QueryPerformanceFrequency(timer_t *);
    }
}
else version (AArch64)
{
    // We cannot use ldc.intrinsics.llvm_readcyclecounter because that is not an accurate
    // time counter (it is a counter of CPU cycles, where here we want a time clock).
    // Also, priviledged execution rights are needed to enable correct counting with
    // ldc.intrinsics.llvm_readcyclecounter on AArch64.
    extern (D) void QueryPerformanceCounter(timer_t* ctr)
    {
        asm { "mrs %0, cntvct_el0" : "=r" (*ctr); }
    }
    extern (D) void QueryPerformanceFrequency(timer_t* freq)
    {
        asm { "mrs %0, cntfrq_el0" : "=r" (*freq); }
    }
}
else version (LDC)
{
    extern (D) void QueryPerformanceCounter(timer_t* ctr)
    {
        import ldc.intrinsics: llvm_readcyclecounter;
        *ctr = llvm_readcyclecounter();
    }
}
else
{
    extern (D) void QueryPerformanceCounter(timer_t* ctr)
    {
        version (D_InlineAsm_X86)
        {
            asm
            {
                naked                   ;
                mov       ECX,EAX       ;
                rdtsc                   ;
                mov   [ECX],EAX         ;
                mov   [ECX+4],EDX        ;
                ret                     ;
            }
        }
        else version (D_InlineAsm_X86_64)
        {
            asm
            {
                naked                   ;
                // rdtsc can produce skewed results without preceding lfence/mfence.
                // this is what GNU/Linux does, but only use mfence here.
                // see https://github.com/torvalds/linux/blob/03b9730b769fc4d87e40f6104f4c5b2e43889f19/arch/x86/include/asm/msr.h#L130-L154
                mfence                  ; // serialize rdtsc instruction.
                rdtsc                   ;
                mov   [RDI],EAX         ;
                mov   [RDI+4],EDX        ;
                ret                     ;
            }
        }
        else
        {
            static assert(0);
        }
    }
}
