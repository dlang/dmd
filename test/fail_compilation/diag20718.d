/*
EXTRA_FILES: imports/diag20718mod.d
TEST_OUTPUT:
---
fail_compilation/diag20718.d(16): Error: cannot implicitly convert expression `123` of type `int` to `immutable(string)`
---
*/

import imports.diag20718mod;

struct S
{
    string x;
}

static immutable S s = {foo};
