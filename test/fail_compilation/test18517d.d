/*
REQUIRED_ARGS: -I=fail_compilation/imports fail_compilation/imports/import18517d.d fail_compilation/imports/import18517c.d
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/imports/import18517c.d(1): Error: module `import18517b` from file fail_compilation/imports/import18517a.d conflicts with another module import18517a from file fail_compilation/imports/import18517b.d
---
*/
import import18517c, import18517d;
