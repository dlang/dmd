// https://issues.dlang.org/show_bug.cgi?id=21096

/*
TEST_OUTPUT:
---
fail_compilation/test21096.d(13): Error: identifier or new keyword expected following `(...)`.
char[(void*).];
            ^
fail_compilation/test21096.d(13): Error: no identifier for declarator `char[(__error)]`
---
*/

char[(void*).];
