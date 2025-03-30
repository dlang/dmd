// https://issues.dlang.org/show_bug.cgi?id=22877

int array[3];
_Static_assert(sizeof(array) == 3 * sizeof(int), "array");

_Static_assert(sizeof("ab") == 3, "string");
_Static_assert((sizeof(L"ab") == 3 * sizeof(short)) ||
               (sizeof(L"ab") == 3 * sizeof(int)), "wstring");
_Static_assert(sizeof(u8"ab") == 3, "UTF-8 string");
_Static_assert(sizeof(u"ab") == 3 * sizeof(short), "UTF-16 string");
_Static_assert(sizeof(U"ab") == 3 * sizeof(int), "UTF-32 string");

_Static_assert(sizeof(&"ab") == sizeof(void*), "pointer");
_Static_assert(sizeof(*&"ab") == 3, "pointer deref");
