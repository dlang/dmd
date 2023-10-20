/* TEST_OUTPUT:
---
fail_compilation/cconst1.c(104): Error: cannot modify `const` expression `i`
fail_compilation/cconst1.c(106): Error: cannot modify `const` expression `j`
---
*/

#line 100

void test100()
{
    const int i;
    ++i;
    int const j;
    ++j;
    int *const p;
    ++p;
    int *const x, y;
    ++y; // this should pass
}
