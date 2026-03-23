void* test_memcpy(void* dest, const void* src, unsigned long n)
{
    return __builtin_memcpy(dest, src, n);
}

void* test_memmove(void* dest, const void* src, unsigned long n)
{
    return __builtin_memmove(dest, src, n);
}

void* test_memset(void* s, int c, unsigned long n)
{
    return __builtin_memset(s, c, n);
}

int test_memcmp(const void* s1, const void* s2, unsigned long n)
{
    return __builtin_memcmp(s1, s2, n);
}

int test_strcmp(const char* s1, const char* s2)
{
    return __builtin_strcmp(s1, s2);
}

char* test_strcpy(char* dest, const char* src)
{
    return __builtin_strcpy(dest, src);
}

unsigned long test_strlen(const char* s)
{
    return __builtin_strlen(s);
}
