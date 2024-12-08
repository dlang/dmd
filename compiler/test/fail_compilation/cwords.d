/* TEST_OUTPUT:
---
fail_compilation/cwords.d(21): Error: undefined identifier `FALSE`, did you mean `false`?
    bool a = FALSE;
             ^
fail_compilation/cwords.d(22): Error: undefined identifier `TRUE`, did you mean `true`?
    bool b = TRUE;
             ^
fail_compilation/cwords.d(23): Error: undefined identifier `NULL`, did you mean `null`?
    int* p = NULL;
             ^
fail_compilation/cwords.d(24): Error: undefined identifier `unsigned`, did you mean `uint`?
    unsigned u;
             ^
---
*/


void foo()
{
    bool a = FALSE;
    bool b = TRUE;
    int* p = NULL;
    unsigned u;
}
