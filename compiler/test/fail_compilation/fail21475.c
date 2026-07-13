/*
TEST_OUTPUT:
---
fail_compilation/fail21475.c(12): Error: expression expected, not `)`
fail_compilation/fail21475.c(12): Error: found `=>` when expecting `)`
fail_compilation/fail21475.c(12): Error: found `0` when expecting `)`
fail_compilation/fail21475.c(12): Error: found `)` when expecting `;` following statement
---
*/
void test21745(void)
{
    __check(() => 0);
}
