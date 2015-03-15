// REQUIRED_ARGS: -de
short s;
ushort us;
int i;
uint ui;
long l;
ulong ul;
// 0. same-signed-ness
static assert(__traits(compiles, ui>ul));
static assert(__traits(compiles, ul>ui));
static assert(__traits(compiles, i>l));
static assert(__traits(compiles, l>i));
static assert(!(1>2));
static assert(2>1);
static assert(!(-1>2));
static assert(2>-1);
// 1. sizeof(signed) > sizeof(unsigned)
static assert(__traits(compiles, l>ui));
static assert(__traits(compiles, ui>l));
static assert(!(-1L>2));
static assert(2>-1L);
// 1b. sizeof(common) > sizeof(either)
static assert(__traits(compiles, s>us));
static assert(__traits(compiles, us>s));
static assert(!(cast(short)-1>cast(ushort)2));
static assert(cast(ushort)2>cast(short)-1);
// 2. signed.min >= 0
static assert(__traits(compiles, ui>cast(int)2));
static assert(__traits(compiles, cast(int)2>ui));
static assert(__traits(compiles, ul>cast(int)2));
static assert(__traits(compiles, cast(int)2>ul));
// 3. unsigned.max < typeof(unsigned.max/2) => ERROR
static assert(!__traits(compiles, i>cast(uint)2));
static assert(!__traits(compiles, cast(uint)2>i));
static assert(!__traits(compiles, cast(int)-1>cast(uint)3));
static assert(!__traits(compiles, cast(uint)3>cast(int)-1));
static assert(!__traits(compiles, -1>2UL));
static assert(!__traits(compiles, 2UL>-1));
// error
static assert(!__traits(compiles, ul>-2));
static assert(!__traits(compiles, -2>ul));
static assert(!__traits(compiles, i>ul));
static assert(!__traits(compiles, ul>i));
static assert(!__traits(compiles, l>ul));
static assert(!__traits(compiles, ul>l));
static assert(!__traits(compiles, i>ui));
static assert(!__traits(compiles, ui>i));

