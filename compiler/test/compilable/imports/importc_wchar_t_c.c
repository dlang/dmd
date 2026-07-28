
#include <stddef.h>

_Static_assert(sizeof(__importc_char) == 1, "sizeof(__importc_char) == 1");
_Static_assert(sizeof(__importc_wchar) == 2, "sizeof(__importc_wchar) == 2");
_Static_assert(sizeof(__importc_dchar) == 4, "sizeof(__importc_dchar) == 4");

typedef struct
{
    wchar_t w;
    wchar_t *p;
} wchar_t_aggregate;

void accept_wchar_t_string(const wchar_t *str)
{}

#ifdef _MSC_VER
    void accept_msvc___wchar_t_string(const __wchar_t *str)
    {}
#endif
