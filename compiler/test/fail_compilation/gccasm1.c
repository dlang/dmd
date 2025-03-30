/* TEST_OUTPUT:
---
fail_compilation/gccasm1.c(12): Error: string literal expected for Assembler Template, not `%`
---
 */

#define	__fldcw(addr)	asm volatile(%0 : : "m" (*(addr)))

static __inline void
__fnldcw(unsigned short _cw, unsigned short _newcw)
{
        __fldcw(&_newcw);
}

void main()
{
    __fnldcw(1, 2);
}
