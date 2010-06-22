// EXTRA_SOURCES: imports/test40a.d
// PERMUTE_ARGS:
// REQUIRED_ARGS: -d

import std.stdio;
import imports.test40a;

class Foo {
        mixin Mix;
}


void main() {
        Bar.foobar();
}

