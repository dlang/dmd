/*
TEST_OUTPUT:
---
fail_compilation/diag12400.d(11): Error: undefined identifier 'Unqual' in module imports.a12400
fail_compilation/diag12400.d(12): Error: undefined identifier 'Unqual' in module imports.a12400
---
*/

import imports.a12400;  // std.tyoecons

alias imports.a12400.Unqual!int X;
alias imports.a12400.Unqual X2;
