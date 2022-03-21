// https://issues.dlang.org/show_bug.cgi?id=22877

int array[3];
_Static_assert(sizeof(array) == 3 * sizeof(int), "array");

_Static_assert(sizeof("a") == 2, "string");
_Static_assert((sizeof(L"ab") == 3 * 2) || (sizeof(L"ab") == 3 * 4), "wstring");
