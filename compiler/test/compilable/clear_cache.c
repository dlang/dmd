// __builtin___clear_cache is used by JIT code such as sljit

#if defined(__x86_64__) || defined(_M_X64) || defined(__i386__) || defined(_M_IX86)

void flush(char *begin, char *end)
{
    __builtin___clear_cache(begin, end);
}

#endif
