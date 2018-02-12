/*
EXTRA_SOURCES: imports/dip22c.d
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/dip22b.d(13): Deprecation: `pkg.dip22c.Foo` is not visible from module `dip22`
---
*/
module pkg.dip22;

import imports.dip22b;

Foo foo;
