/*
REQUIRED_ARGS: -I=fail_compilation/imports
PERMUTE_ARGS:
BROKEN:
TEST_OUTPUT:
---
fail_compilation/test18517b.d(19): Error: module `import18517b` from file fail_compilation/imports/import18517a.d conflicts with another module import18517a from file fail_compilation/imports/import18517b.d
---
*/

/*
The second import must fail because the module name of the first import is
the same as the module name of the second import.  The compiler MUST cause
this to fail, because if it doesn't then switching the import order would
result in a different file being loaded for module import18517a breaking
import order invarance.
*/
import import18517b;
import import18517a;
