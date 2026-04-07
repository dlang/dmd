// https://issues.dlang.org/show_bug.cgi?id=20012

mixin template mixinFoo() {

    extern(C) void cFoo() {}

    extern(C) int cVar;
    extern(D) int dVar;

    void dFoo() {}

    mixin(`mixin mixinBar;`); // test nesting and interaction with string mixins
}

mixin mixinFoo;

mixin template mixinBar() {
    extern(C) void cBar() {}
    void dBar() {}
}

static assert(cFoo.mangleof == "cFoo");
static assert(dFoo.mangleof == "_D21mixinTemplateMangling14__mixin_L15_C14dFooFZv");
static assert(cVar.mangleof == "cVar");
static assert(dVar.mangleof == "_D21mixinTemplateMangling14__mixin_L15_C14dVari");
static assert(cBar.mangleof == "cBar");
static assert(dBar.mangleof == "_D21mixinTemplateMangling14__mixin_L15_C114__mixin_L12_C14dBarFZv");

struct S {
    mixin mixinFoo;
    static assert(cFoo.mangleof == "_D21mixinTemplateMangling1S14__mixin_L30_C54cFooMUZv");
    static assert(cBar.mangleof == "_D21mixinTemplateMangling1S14__mixin_L30_C514__mixin_L12_C14cBarMUZv");
    static assert(dBar.mangleof == "_D21mixinTemplateMangling1S14__mixin_L30_C514__mixin_L12_C14dBarMFZv");
    static assert(dFoo.mangleof == "_D21mixinTemplateMangling1S14__mixin_L30_C54dFooMFZv");
}
