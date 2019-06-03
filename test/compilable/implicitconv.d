enum __c_wchar_t : wchar;

alias wchar_t = __c_wchar_t;

immutable(wchar_t)[] a = "somestring";
const(wchar_t)[]     b = "somestring";
immutable(wchar_t)*  c = "somestring";
const(wchar_t)*      d = "somestring";

string foo = "foo";

static assert(!__traits(compiles, { immutable(wchar_t)[] bar = foo; } ));
static assert(!__traits(compiles, { const(wchar_t)[]     bar = foo; } ));
static assert(!__traits(compiles, { immutable(wchar_t)*  bar = foo; } ));
static assert(!__traits(compiles, { const(wchar_t)*      bar = foo; } ));

