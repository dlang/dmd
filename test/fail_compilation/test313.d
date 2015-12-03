/*
TEST_OUTPUT:
---
fail_compilation/test313.d(14): Error: 'printf' is not defined, perhaps you need to import core.stdc.stdio; ?
fail_compilation/test313.d(15): Error: undefined identifier 'core'
---
*/
module test313;

import imports.a313;

void main()
{
    printf("foo\n");
    core.stdc.stdio.printf("foo\n");
}
