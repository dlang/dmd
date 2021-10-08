/*
REQUIRED_ARGS: -w -o-

More complex examples from the DIP
https://github.com/dlang/DIPs/blob/master/DIPs/accepted/DIP1034.md
*/

alias noreturn = typeof(*null);
static assert (!is(noreturn == void));

void initialize()
{
    noreturn a;
    noreturn b = noreturn.init;
}

void foo(const noreturn);
void foo(const int);

noreturn bar();

void overloads()
{
    noreturn n;
    foo(n);

    foo(bar());
}

void inference()
{
    auto inf = cast(noreturn) 1;
    static assert(is(typeof(inf) == noreturn));

    noreturn n;
    auto c = cast(const shared noreturn) n;
    static assert(is(typeof(c) == const shared noreturn));
    static assert(is(typeof(n) == noreturn));

    auto c2 = cast(immutable noreturn) n;
    static assert(is(typeof(c) == const shared noreturn));
    static assert(is(typeof(c2) == immutable noreturn));
    static assert(is(typeof(n) == noreturn));
}


/******************************************************************************/
// https://issues.dlang.org/show_bug.cgi?id=21957
// Calculate proper alignment and size for noreturn members

enum longPad = long.alignof - int.sizeof;

struct BasicStruct
{
	int firstInt;
	noreturn noRet;
	long lastLong;
}

static assert(BasicStruct.sizeof == (int.sizeof + longPad + long.sizeof));

static assert(BasicStruct.firstInt.offsetof == 0);
static assert(BasicStruct.noRet.offsetof == 4);
static assert(BasicStruct.lastLong.offsetof == (4 + longPad));

struct AlignedStruct
{
	int firstInt;
	align(16) noreturn noRet;
	long lastLong;
}

static assert(AlignedStruct.sizeof == 32);

static assert(AlignedStruct.firstInt.offsetof == 0);
static assert(AlignedStruct.noRet.offsetof == 16);
static assert(AlignedStruct.lastLong.offsetof == 16);

union BasicUnion
{
	int firstInt;
	noreturn noRet;
	long lastLong;
}

static assert(BasicUnion.sizeof == 8);

static assert(BasicUnion.firstInt.offsetof == 0);
static assert(BasicUnion.noRet.offsetof == 0);
static assert(BasicUnion.lastLong.offsetof == 0);

union AlignedUnion
{
	int firstInt;
	align(16) noreturn noRet;
	long lastLong;
}

static assert(AlignedUnion.sizeof == 16);

static assert(AlignedUnion.firstInt.offsetof == 0);
static assert(AlignedUnion.noRet.offsetof == 0);
static assert(AlignedUnion.lastLong.offsetof == 0);

class BasicClass
{
	int firstInt;
	noreturn noRet;
	long lastLong;
}

enum objectMemberSize = __traits(classInstanceSize, Object);

static assert(__traits(classInstanceSize, BasicClass) == objectMemberSize + (int.sizeof + longPad + long.sizeof));

static assert(BasicClass.firstInt.offsetof == objectMemberSize + 0);
static assert(BasicClass.noRet.offsetof == objectMemberSize + 4);
static assert(BasicClass.lastLong.offsetof == objectMemberSize + (4 + longPad));

class AlignedClass
{
	int firstInt;
	align(16) noreturn noRet;
	long lastLong;
}

enum offset = (objectMemberSize + 4 + 16) & ~15;

static assert(__traits(classInstanceSize, AlignedClass) == offset + 8);

static assert(AlignedClass.firstInt.offsetof == objectMemberSize + 0);
static assert(AlignedClass.noRet.offsetof == offset);
static assert(AlignedClass.lastLong.offsetof == offset);

struct EmptyStruct
{
	noreturn noRet;
}

static assert(EmptyStruct.sizeof == 1);
static assert(EmptyStruct.noRet.offsetof == 0);

struct EmptyStruct2
{
	noreturn[4] noRet;
}

static assert(EmptyStruct2.sizeof == 1);
static assert(EmptyStruct2.noRet.offsetof == 0);
