#include "valgrind.h" /*<valgrind/valgrind.h>*/
#include "memcheck.h" /*<valgrind/memcheck.h>*/
#include <stddef.h> /* for size_t */

void _d_valgrind_make_mem_noaccess(const void* addr, size_t len)
{
    VALGRIND_MAKE_MEM_NOACCESS(addr, len);
}

void _d_valgrind_make_mem_undefined(const void* addr, size_t len)
{
    VALGRIND_MAKE_MEM_UNDEFINED(addr, len);
}

void _d_valgrind_make_mem_defined(const void* addr, size_t len)
{
    VALGRIND_MAKE_MEM_DEFINED(addr, len);
}
