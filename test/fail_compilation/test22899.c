/* TEST_OUTPUT:
---
fail_compilation/test22899.c(105): Error: expression expected, not `)`
fail_compilation/test22899.c(105): Error: found `;` when expecting `)`
fail_compilation/test22899.c(106): Error: found `}` when expecting `;` following statement
---
*/

// https://issues.dlang.org/show_bug.cgi?id=22904

#line 100

typedef int mytype_t;
void fn()
{
    int x;
    x = sizeof( (mytype_t) );
}}
