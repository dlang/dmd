// PERMUTE_ARGS:

class C12543;
static assert(C12543.sizeof == (void*).sizeof);
static assert(C12543.alignof == (void*).sizeof);
static assert(C12543.mangleof == "C11fwdref125436C12543");

/***************************************************/
// 13564

enum E14010;
static assert(E14010.mangleof == "E11fwdref125436E14010");

struct S14010;
static assert(S14010.mangleof == "S11fwdref125436S14010");
