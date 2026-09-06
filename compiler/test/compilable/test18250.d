// https://github.com/dlang/dmd/issues/18250
extern(C) void f() { }
static assert(typeof(&f).stringof == "extern(C) void function()");
