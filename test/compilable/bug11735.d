// PERMUTE_ARGS:
// REQUIRED_ARGS:

/*
TEST_OUTPUT:
---
print string
print wstring
print dstring
يطبع الترميز الموحد
يطبع الترميز الموحد
يطبع الترميز الموحد
---
*/

pragma(msg, "print string");
pragma(msg, "print wstring"w);
pragma(msg, "print dstring"d);

pragma(msg, "يطبع الترميز الموحد");
pragma(msg, "يطبع الترميز الموحد"w);
pragma(msg, "يطبع الترميز الموحد"d);
