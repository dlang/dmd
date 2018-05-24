/*
REQUIRED_ARGS: -I=fail_compilation/imports fail_compilation/imports/import18517c.d fail_compilation/imports/import18517d.d
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/imports/import18517d.d(1): Error: module `import18517a` from file fail_compilation/imports/import18517b.d conflicts with another module import18517b from file fail_compilation/imports/import18517a.d
---
*/
import import18517c, import18517d;
