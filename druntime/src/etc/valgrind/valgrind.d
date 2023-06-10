module etc.valgrind.valgrind;

debug(VALGRIND):

extern(C) nothrow
{
    void _d_valgrind_make_mem_noaccess (const(void)* addr, size_t len);
    void _d_valgrind_make_mem_undefined(const(void)* addr, size_t len);
    void _d_valgrind_make_mem_defined  (const(void)* addr, size_t len);
}

void makeMemNoAccess (const(void)[] mem) nothrow { _d_valgrind_make_mem_noaccess (mem.ptr, mem.length); }
void makeMemUndefined(const(void)[] mem) nothrow { _d_valgrind_make_mem_undefined(mem.ptr, mem.length); }
void makeMemDefined  (const(void)[] mem) nothrow { _d_valgrind_make_mem_defined  (mem.ptr, mem.length); }
