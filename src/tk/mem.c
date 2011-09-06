/*_ mem.c       */
/* Memory management package    */
/* Written by Walter Bright     */

#include        <stdio.h>
#if MSDOS || __OS2__ || __NT__ || _WIN32
#include        <io.h>
#else
#define _near
#include        <sys/time.h>
#include        <sys/resource.h>
#include        <unistd.h>
#endif
#include        <stdarg.h>
#include        <stddef.h>

#if __cplusplus
#if __DMC__
#include        <new.h>
#else
#include        <new>
#endif
#endif

#ifndef malloc
#if __SC__ || __DMC__ ||  _MSC_VER
#include        <malloc.h>
#else
#include        <stdlib.h>
#endif
#endif

#ifndef MEM_H
#include        "mem.h"
#endif

#ifndef MEM_NOMEMCOUNT
#define MEM_NOMEMCOUNT  0
#endif

#if !MEM_NONE

#ifndef assert
#include        <assert.h>
#endif

#ifndef VAX11C
#ifdef BSDUNIX
#include <strings.h>
#else
#include <string.h>
#endif
#else
extern char *strcpy(),*memcpy();
extern int strlen();
#endif  /* VAX11C */

int mem_inited = 0;             /* != 0 if initialized                  */

static int mem_behavior = MEM_ABORTMSG;
static int (*oom_fp)(void) = NULL;  /* out-of-memory handler                */
static int mem_count;           /* # of allocs that haven't been free'd */
static int mem_scount;          /* # of sallocs that haven't been free'd */

/* Determine where to send error messages       */
#if _WINDLL
void err_message(const char *,...);
#define PRINT   err_message(
#elif MSDOS
#define PRINT   printf( /* stderr can't be redirected with MS-DOS       */
#else
#define ferr    stderr
#define PRINT   fprintf(ferr,
#endif

/*******************************/

void mem_setexception(enum MEM_E flag,...)
{   va_list ap;
    typedef int (*fp_t)(void);

    mem_behavior = flag;
    va_start(ap,flag);
    oom_fp = (mem_behavior == MEM_CALLFP) ? va_arg(ap,fp_t) : 0;
    va_end(ap);
#if MEM_DEBUG
    assert(0 <= flag && flag <= MEM_RETRY);
#endif
}

/*************************
 * This is called when we're out of memory.
 * Returns:
 *      1:      try again to allocate the memory
 *      0:      give up and return NULL
 */

int mem_exception()
{   int behavior;

    behavior = mem_behavior;
    while (1)
    {
        switch (behavior)
        {
            case MEM_ABORTMSG:
#if MSDOS || __OS2__ || __NT__ || _WIN32
                /* Avoid linking in buffered I/O */
            {   static char msg[] = "Fatal error: out of memory\r\n";

                write(1,msg,sizeof(msg) - 1);
            }
#else
                PRINT "Fatal error: out of memory\n");
#endif
                /* FALL-THROUGH */
            case MEM_ABORT:
                exit(EXIT_FAILURE);
                /* NOTREACHED */
            case MEM_CALLFP:
                assert(oom_fp);
                behavior = (*oom_fp)();
                break;
            case MEM_RETNULL:
                return 0;
            case MEM_RETRY:
                return 1;
            default:
                assert(0);
        }
    }
}

/****************************/

#if MEM_DEBUG

#undef mem_strdup

char *mem_strdup(const char *s)
{
        return mem_strdup_debug(s,__FILE__,__LINE__);
}

char *mem_strdup_debug(const char *s,const char *file,int line)
{
        char *p;

        p = s
            ? (char *) mem_malloc_debug((unsigned) strlen(s) + 1,file,line)
            : NULL;
        return p ? strcpy(p,s) : p;
}
#else
char *mem_strdup(const char *s)
{
        char *p;
        int len;

        if (s)
        {   len = strlen(s) + 1;
            p = (char *) mem_malloc(len);
            if (p)
                return (char *)memcpy(p,s,len);
        }
        return NULL;
}

#endif /* MEM_DEBUG */

/************* C++ Implementation ***************/

#if __cplusplus && !MEM_NONE
extern "C++"
{

/* Cause initialization and termination functions to be called  */
#if 0
static struct cMemDebug
{
    cMemDebug() { mem_init(); }
   ~cMemDebug() { mem_term(); }
} dummy;
#endif

int __mem_line;
char *__mem_file;

/********************
 */

#if __GNUC__
int (*_new_handler)(void);
#else
void (*_new_handler)(void);
#endif

/*****************************
 * Replacement for the standard C++ library operator new().
 */

#if !MEM_NONEW

#if __GNUC__
void * operator new(size_t size)
#else
#undef new
void * __cdecl operator new(size_t size)
#endif
{   void *p;

    while (1)
    {
        if (size == 0)
            size++;
#if MEM_DEBUG
        assert(mem_inited);
        p = mem_malloc_debug(size,__mem_file,__mem_line);
#else
        p = mem_malloc((unsigned)size);
#endif
        if (p != NULL || _new_handler == NULL)
            break;
        (*_new_handler)();
    }
    return p;
}

#if __GNUC__
void * operator new[](size_t size)
#else
void * __cdecl operator new[](size_t size)
#endif
{   void *p;

    while (1)
    {
        if (size == 0)
            size++;
#if MEM_DEBUG
        assert(mem_inited);
        p = mem_malloc_debug(size,__mem_file,__mem_line);
#else
        p = mem_malloc((unsigned)size);
#endif
        if (p != NULL || _new_handler == NULL)
            break;
        (*_new_handler)();
    }
    return p;
}

/***********************
 * Replacement for the standard C++ library operator delete().
 */

#undef delete
void __cdecl operator delete(void *p)
{
#if MEM_DEBUG
        assert(mem_inited);
        mem_free_debug(p,__mem_file,__mem_line);
#else
        mem_free(p);
#endif
}

void __cdecl operator delete[](void *p)
{
#if MEM_DEBUG
        assert(mem_inited);
        mem_free_debug(p,__mem_file,__mem_line);
#else
        mem_free(p);
#endif
}
#endif
}
#endif

#if MEM_DEBUG

static long mem_maxalloc;       /* max # of bytes allocated             */
static long mem_numalloc;       /* current # of bytes allocated         */

#define BEFOREVAL       0x4F464542      /* value to detect underrun     */
#define AFTERVAL        0x45544641      /* value to detect overrun      */

#if SUN || SUN386
static long afterval = AFTERVAL;        /* so we can do &afterval       */
#endif

/* The following should be selected to give maximum probability that    */
/* pointers loaded with these values will cause an obvious crash. On    */
/* Unix machines, a large value will cause a segment fault.             */
/* MALLOCVAL is the value to set malloc'd data to.                      */

#if MSDOS || __OS2__ || __NT__ || _WIN32
#define BADVAL          0xFF
#define MALLOCVAL       0xEE
#else
#define BADVAL          0x7A
#define MALLOCVAL       0xEE
#endif

/* Disable mapping macros       */
#undef  mem_malloc
#undef  mem_calloc
#undef  mem_realloc
#undef  mem_free

/* Create a list of all alloc'ed pointers, retaining info about where   */
/* each alloc came from. This is a real memory and speed hog, but who   */
/* cares when you've got obscure pointer bugs.                          */

static struct mem_debug
{
    struct mem_debug *Mnext;    /* next in list                         */
    struct mem_debug *Mprev;    /* previous value in list               */
    const char *Mfile;          /* filename of where allocated          */
    int Mline;                  /* line number of where allocated       */
    unsigned Mnbytes;           /* size of the allocation               */
    unsigned long Mbeforeval;   /* detect underrun of data              */
    char data[1];               /* the data actually allocated          */
} mem_alloclist =
{
        (struct mem_debug *) NULL,
        (struct mem_debug *) NULL,
        NULL,
        11111,
        0,
        BEFOREVAL,
#if !(linux || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun&&__SVR4)
        AFTERVAL
#endif
};

/* Determine allocation size of a mem_debug     */
#define mem_debug_size(n)       (sizeof(struct mem_debug) - 1 + (n) + sizeof(AFTERVAL))

/* Convert from a void *to a mem_debug struct.  */
#define mem_ptrtodl(p)  ((struct mem_debug *) ((char *)p - offsetof(struct mem_debug,data[0])))

/* Convert from a mem_debug struct to a mem_ptr.        */
#define mem_dltoptr(dl) ((void *) &((dl)->data[0]))

/*****************************
 * Set new value of file,line
 */

void mem_setnewfileline( void *ptr, const char *fil, int lin)
{
    struct mem_debug *dl;

    dl = mem_ptrtodl(ptr);
    dl->Mfile = fil;
    dl->Mline = lin;
}

/****************************
 * Print out struct mem_debug.
 */

static void _near mem_printdl(struct mem_debug *dl)
{
        PRINT "alloc'd from file '%s' line %d nbytes %d ptr %p\n",
                dl->Mfile,dl->Mline,dl->Mnbytes,(long)mem_dltoptr(dl));
}

/****************************
 * Print out file and line number.
 */

static void _near mem_fillin(const char *fil, int lin)
{
        PRINT "File '%s' line %d\n",fil,lin);
#ifdef ferr
        fflush(ferr);
#endif
}

/****************************
 * If MEM_DEBUG is not on for some modules, these routines will get
 * called.
 */

void *mem_calloc(unsigned u)
{
        return mem_calloc_debug(u,__FILE__,__LINE__);
}

void *mem_malloc(unsigned u)
{
        return mem_malloc_debug(u,__FILE__,__LINE__);
}

void *mem_realloc(void *p, unsigned u)
{
        return mem_realloc_debug(p,u,__FILE__,__LINE__);
}

void mem_free(void *p)
{
        mem_free_debug(p,__FILE__,__LINE__);
}


/**************************/

void mem_freefp(void *p)
{
        mem_free(p);
}

/***********************
 * Debug versions of mem_calloc(), mem_free() and mem_realloc().
 */

void *mem_malloc_debug(unsigned n, const char *fil, int lin)
{   void *p;

    p = mem_calloc_debug(n,fil,lin);
    if (p)
        memset(p,MALLOCVAL,n);
    return p;
}

void *mem_calloc_debug(unsigned n, const char *fil, int lin)
{
    struct mem_debug *dl;

    do
        dl = (struct mem_debug *) calloc(mem_debug_size(n),1);
    while (dl == NULL && mem_exception());
    if (dl == NULL)
        return NULL;
    dl->Mfile = fil;
    dl->Mline = lin;
    dl->Mnbytes = n;
    dl->Mbeforeval = BEFOREVAL;
#if SUN || SUN386 /* bus error if we store a long at an odd address */
    memcpy(&(dl->data[n]),&afterval,sizeof(AFTERVAL));
#else
    *(long *) &(dl->data[n]) = AFTERVAL;
#endif

    /* Add dl to start of allocation list       */
    dl->Mnext = mem_alloclist.Mnext;
    dl->Mprev = &mem_alloclist;
    mem_alloclist.Mnext = dl;
    if (dl->Mnext != NULL)
        dl->Mnext->Mprev = dl;

    mem_count++;
    mem_numalloc += n;
    if (mem_numalloc > mem_maxalloc)
        mem_maxalloc = mem_numalloc;
    return mem_dltoptr(dl);
}

void mem_free_debug(void *ptr, const char *fil, int lin)
{
        struct mem_debug *dl;

        if (ptr == NULL)
                return;
        if (mem_count <= 0)
        {       PRINT "More frees than allocs at ");
                goto err;
        }
        dl = mem_ptrtodl(ptr);
        if (dl->Mbeforeval != BEFOREVAL)
        {
                PRINT "Pointer x%lx underrun\n",(long)ptr);
                PRINT "'%s'(%d)\n",fil,lin);
                goto err2;
        }
#if SUN || SUN386 /* Bus error if we read a long from an odd address    */
        if (memcmp(&dl->data[dl->Mnbytes],&afterval,sizeof(AFTERVAL)) != 0)
#else
        if (*(long *) &dl->data[dl->Mnbytes] != AFTERVAL)
#endif
        {
                PRINT "Pointer x%lx overrun\n",(long)ptr);
                goto err2;
        }
        mem_numalloc -= dl->Mnbytes;
        if (mem_numalloc < 0)
        {       PRINT "error: mem_numalloc = %ld, dl->Mnbytes = %d\n",
                        mem_numalloc,dl->Mnbytes);
                goto err2;
        }

        /* Remove dl from linked list   */
        if (dl->Mprev)
                dl->Mprev->Mnext = dl->Mnext;
        if (dl->Mnext)
                dl->Mnext->Mprev = dl->Mprev;

        /* Stomp on the freed storage to help detect references */
        /* after the storage was freed.                         */
        memset((void *) dl,BADVAL,sizeof(*dl) + dl->Mnbytes);
        mem_count--;

        free((void *) dl);
        return;

err2:
        mem_printdl(dl);
err:
        PRINT "free'd from ");
        mem_fillin(fil,lin);
        assert(0);
        /* NOTREACHED */
}

/*******************
 * Debug version of mem_realloc().
 */

void *mem_realloc_debug(void *oldp, unsigned n, const char *fil, int lin)
{   void *p;
    struct mem_debug *dl;

    if (n == 0)
    {   mem_free_debug(oldp,fil,lin);
        p = NULL;
    }
    else if (oldp == NULL)
        p = mem_malloc_debug(n,fil,lin);
    else
    {
        p = mem_malloc_debug(n,fil,lin);
        if (p != NULL)
        {
            dl = mem_ptrtodl(oldp);
            if (dl->Mnbytes < n)
                n = dl->Mnbytes;
            memcpy(p,oldp,n);
            mem_free_debug(oldp,fil,lin);
        }
    }
    return p;
}

/***************************/

static void mem_checkdl(struct mem_debug *dl)
{   void *p;
#if (__SC__ || __DMC__) && !_WIN32
    unsigned u;

    /* Take advantage of fact that SC's allocator stores the size of the
     * alloc in the unsigned immediately preceding the allocation.
     */
    u = ((unsigned *)dl)[-1] - sizeof(unsigned);
    assert((u & (sizeof(unsigned) - 1)) == 0 && u >= mem_debug_size(dl->Mnbytes));
#endif
    p = mem_dltoptr(dl);
    if (dl->Mbeforeval != BEFOREVAL)
    {
            PRINT "Pointer x%lx underrun\n",(long)p);
            goto err2;
    }
#if SUN || SUN386 /* Bus error if we read a long from an odd address    */
    if (memcmp(&dl->data[dl->Mnbytes],&afterval,sizeof(AFTERVAL)) != 0)
#else
    if (*(long *) &dl->data[dl->Mnbytes] != AFTERVAL)
#endif
    {
            PRINT "Pointer x%lx overrun\n",(long)p);
            goto err2;
    }
    return;

err2:
    mem_printdl(dl);
    assert(0);
}

/***************************/

void mem_check()
{   register struct mem_debug *dl;

#if (__SC__ || _MSC_VER) && !defined(malloc)
    int i;

    i = _heapset(0xF4);
    assert(i == _HEAPOK);
#endif
    for (dl = mem_alloclist.Mnext; dl != NULL; dl = dl->Mnext)
        mem_checkdl(dl);
}

/***************************/

void mem_checkptr(void *p)
{   register struct mem_debug *dl;

    for (dl = mem_alloclist.Mnext; dl != NULL; dl = dl->Mnext)
    {
        if (p >= (void *) &(dl->data[0]) &&
            p < (void *)((char *)dl + sizeof(struct mem_debug)-1 + dl->Mnbytes))
            goto L1;
    }
    assert(0);

L1:
    mem_checkdl(dl);
}

#else

/***************************/

void *mem_malloc(unsigned numbytes)
{       void *p;

        if (numbytes == 0)
                return NULL;
        while (1)
        {
                p = malloc(numbytes);
                if (p == NULL)
                {       if (mem_exception())
                                continue;
                }
#if !MEM_NOMEMCOUNT
                else
                        mem_count++;
#endif
                break;
        }
        /*printf("malloc(%d) = x%lx, mem_count = %d\n",numbytes,p,mem_count);*/
        return p;
}

/***************************/

void *mem_calloc(unsigned numbytes)
{       void *p;

        if (numbytes == 0)
            return NULL;
        while (1)
        {
                p = calloc(numbytes,1);
                if (p == NULL)
                {       if (mem_exception())
                                continue;
                }
#if !MEM_NOMEMCOUNT
                else
                        mem_count++;
#endif
                break;
        }
        /*printf("calloc(%d) = x%lx, mem_count = %d\n",numbytes,p,mem_count);*/
        return p;
}

/***************************/

void *mem_realloc(void *oldmem_ptr,unsigned newnumbytes)
{   void *p;

    if (oldmem_ptr == NULL)
        p = mem_malloc(newnumbytes);
    else if (newnumbytes == 0)
    {   mem_free(oldmem_ptr);
        p = NULL;
    }
    else
    {
        do
            p = realloc(oldmem_ptr,newnumbytes);
        while (p == NULL && mem_exception());
    }
    /*printf("realloc(x%lx,%d) = x%lx, mem_count = %d\n",oldmem_ptr,newnumbytes,p,mem_count);*/
    return p;
}

/***************************/

void mem_free(void *ptr)
{
    /*printf("free(x%lx) mem_count=%d\n",ptr,mem_count);*/
    if (ptr != NULL)
    {
#if !MEM_NOMEMCOUNT
        assert(mem_count != 0);
        mem_count--;
#endif
        free(ptr);
    }
}

/***************************/
/* This is our low-rent fast storage allocator  */

static char *heap;
static size_t heapleft;

/***************************/

#if 0 && __SC__ && __INTSIZE == 4 && __I86__ && !_DEBUG_TRACE && _WIN32 && (SCC || SCPP || JAVA)

__declspec(naked) void *mem_fmalloc(unsigned numbytes)
{
    __asm
    {
        mov     EDX,4[ESP]
        mov     EAX,heap
        add     EDX,3
        mov     ECX,heapleft
        and     EDX,~3
        je      L5A
        cmp     EDX,ECX
        ja      L2D
        sub     ECX,EDX
        add     EDX,EAX
        mov     heapleft,ECX
        mov     heap,EDX
        ret     4

L2D:    push    EBX
        mov     EBX,EDX
//      add     EDX,03FFFh
//      and     EDX,~03FFFh
        add     EDX,03C00h
        mov     heapleft,EDX
L3D:    push    heapleft
        call    mem_malloc
        test    EAX,EAX
        mov     heap,EAX
        jne     L18
        call    mem_exception
        test    EAX,EAX
        jne     L3D
        pop     EBX
L5A:    xor     EAX,EAX
        ret     4

L18:    add     heap,EBX
        sub     heapleft,EBX
        pop     EBX
        ret     4
    }
}

#else

void *mem_fmalloc(unsigned numbytes)
{   void *p;

    //printf("fmalloc(%d)\n",numbytes);
#if defined(__llvm__) && (defined(__GNUC__) || defined(__clang__))
    // LLVM-GCC and Clang assume some types, notably elem (see DMD issue 6215),
    // to be 16-byte aligned. Because we do not have any type information
    // available here, we have to 16 byte-align everything.
    numbytes = (numbytes + 0xF) & ~0xF;
#else
    if (sizeof(size_t) == 2)
        numbytes = (numbytes + 1) & ~1;         /* word align   */
    else
        numbytes = (numbytes + 3) & ~3;         /* dword align  */
#endif

    /* This ugly flow-of-control is so that the most common case
       drops straight through.
     */

    if (!numbytes)
        return NULL;

    if (numbytes <= heapleft)
    {
     L2:
        p = (void *)heap;
        heap += numbytes;
        heapleft -= numbytes;
        return p;
    }

#if 1
    heapleft = numbytes + 0x3C00;
    if (heapleft >= 16372)
        heapleft = numbytes;
#elif _WIN32
    heapleft = (numbytes + 0x3FFF) & ~0x3FFF;   /* round to next boundary */
#else
    heapleft = 0x3F00;
    assert(numbytes <= heapleft);
#endif
L1:
    heap = (char *)malloc(heapleft);
    if (!heap)
    {   if (mem_exception())
            goto L1;
        return NULL;
    }
    goto L2;
}

#endif

/***************************/

void *mem_fcalloc(unsigned numbytes)
{   void *p;

    p = mem_fmalloc(numbytes);
    return p ? memset(p,0,numbytes) : p;
}

/***************************/

char *mem_fstrdup(const char *s)
{
        char *p;
        int len;

        if (s)
        {   len = strlen(s) + 1;
            p = (char *) mem_fmalloc(len);
            if (p)
                return (char *)memcpy(p,s,len);
        }
        return NULL;
}

#endif

/***************************/

void mem_init()
{
        if (mem_inited == 0)
        {       mem_count = 0;
                mem_scount = 0;
                oom_fp = NULL;
                mem_behavior = MEM_ABORTMSG;
#if MEM_DEBUG
                mem_numalloc = 0;
                mem_maxalloc = 0;
                mem_alloclist.Mnext = NULL;
#if linux || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun&&__SVR4
                *(long *) &(mem_alloclist.data[0]) = AFTERVAL;
#endif
#endif
#if (__ZTC__ || __SC__ || __DMC__) && !defined(malloc)
                free(malloc(1));        /* initialize storage allocator */
#endif
#if MEM_DEBUG && (__SC__ || _MSC_VER) && !defined(malloc)
                {   int i;

                    i = _heapset(0xF4);
                    assert(i == _HEAPOK);
                }
#endif
        }
        mem_inited++;
}

/***************************/

void mem_term()
{
        if (mem_inited)
        {
#if MEM_DEBUG
                struct mem_debug *dl;

                for (dl = mem_alloclist.Mnext; dl; dl = dl->Mnext)
                {       PRINT "Unfreed pointer: ");
                        mem_printdl(dl);
                }
#if 0
                PRINT "Max amount ever allocated == %ld bytes\n",
                        mem_maxalloc);
#endif
#if (__SC__ || _MSC_VER) && !defined(malloc)
                {   int i;

                    i = _heapset(0xF4);
                    assert(i == _HEAPOK);
                }
#endif
#else
                if (mem_count)
                        PRINT "%d unfreed items\n",mem_count);
                if (mem_scount)
                        PRINT "%d unfreed s items\n",mem_scount);
#endif /* MEM_DEBUG */
                assert(mem_count == 0 && mem_scount == 0);
        }
        mem_inited = 0;
}

#endif /* !MEM_NONE */
