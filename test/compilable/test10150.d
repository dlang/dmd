// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

void foo() {}
alias F = typeof(foo);

class C
{
    const        static void fc() {}
    immutable    static void fi() {}
    inout        static void fw() {}
    shared       static void fs() {}
    shared const static void fsc() {}
    shared inout static void fsw() {}

    static assert(is(typeof(fc) == F));
    static assert(is(typeof(fi) == F));
    static assert(is(typeof(fw) == F));
    static assert(is(typeof(fs) == F));
    static assert(is(typeof(fsc) == F));
    static assert(is(typeof(fsw) == F));
}

const        { void fc() {} }
immutable    { void fi() {} }
inout        { void fw() {} }
shared       { void fs() {} }
shared const { void fsc() {} }
shared inout { void fsw() {} }

static assert(is(typeof(fc) == F));
static assert(is(typeof(fi) == F));
static assert(is(typeof(fw) == F));
static assert(is(typeof(fs) == F));
static assert(is(typeof(fsc) == F));
static assert(is(typeof(fsw) == F));
