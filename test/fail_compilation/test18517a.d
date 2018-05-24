/*
REQUIRED_ARGS: -I=fail_compilation/imports
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/test18517a.d(18): Error: module `import18517a` from file fail_compilation/imports/import18517b.d conflicts with another module import18517b from file fail_compilation/imports/import18517a.d
---
*/

/*
The second import must fail because the module name of the first import is
the same as the module name of the second import.  However, it is important
that the compiler causes this to fail, because if it doesn't then switching
the import order would result in a different file being loaded for
module import18517b.
*/
import import18517a;
import import18517b;
