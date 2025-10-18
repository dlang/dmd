import core.stdc.stdio;
import imports.test40a;

class Foo {
        mixin Mix;
}


shared static this() {
        Bar.foobar();
}
