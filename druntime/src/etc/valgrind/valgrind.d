module etc.valgrind.valgrind;

debug(VALGRIND):

extern(C) nothrow
{
    void _d_valgrind_make_mem_noaccess (const(void)* addr, size_t len);
    void _d_valgrind_make_mem_undefined(const(void)* addr, size_t len);
    void _d_valgrind_make_mem_defined  (const(void)* addr, size_t len);
    uint _d_valgrind_get_vbits(const(void)* addr, ubyte* bits, size_t len);
    uint _d_valgrind_set_vbits(const(void)* addr, ubyte* bits, size_t len);
    void _d_valgrind_disable_addr_reporting_in_range(const(void)* addr, size_t len);
    void _d_valgrind_enable_addr_reporting_in_range (const(void)* addr, size_t len);
}

void makeMemNoAccess (const(void)[] mem) nothrow { _d_valgrind_make_mem_noaccess (mem.ptr, mem.length); }
void makeMemUndefined(const(void)[] mem) nothrow { _d_valgrind_make_mem_undefined(mem.ptr, mem.length); }
void makeMemDefined  (const(void)[] mem) nothrow { _d_valgrind_make_mem_defined  (mem.ptr, mem.length); }

uint getVBits(const(void)[] mem, ubyte[] bits) nothrow
{
    assert(mem.length == bits.length);
    return _d_valgrind_get_vbits(mem.ptr, bits.ptr, mem.length);
}

uint setVBits(const(void)[] mem, ubyte[] bits) nothrow
{
    assert(mem.length == bits.length);
    return _d_valgrind_set_vbits(mem.ptr, bits.ptr, mem.length);
}

void disableAddrReportingInRange(const(void)[] mem) nothrow
{
    _d_valgrind_disable_addr_reporting_in_range(mem.ptr, mem.length);
}

void enableAddrReportingInRange(const(void)[] mem) nothrow
{
    _d_valgrind_enable_addr_reporting_in_range(mem.ptr, mem.length);
}
