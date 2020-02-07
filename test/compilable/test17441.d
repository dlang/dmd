import m1 = imports.test17441foo.bar;
import m2 = imports.test17441foo;
alias p = __traits(parent, m1);
enum e(alias thing) = thing.stringof;

static assert(e!m1 == m1.stringof);
static assert(e!m2 == m2.stringof);
static assert( e!p == p.stringof );
