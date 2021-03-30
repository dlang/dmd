module mod;
static assert(is(mod == module));
static assert(is(mixin("mod") == module));

import imports.test20530a;
static assert(is(imports == package));
static assert(is(mixin("imports") == package));
