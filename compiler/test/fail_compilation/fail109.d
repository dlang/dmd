/*
TEST_OUTPUT:
---
fail_compilation/fail109.d(42): Error: enum member `fail109.Bool.Unknown` initialization with `Bool.True+1` causes overflow for type `bool`
    Unknown
    ^
fail_compilation/fail109.d(48): Error: enum member `fail109.E.B` initialization with `E.A+1` causes overflow for type `int`
fail_compilation/fail109.d(54): Error: enum member `fail109.E1.B` initialization with `E1.A+1` causes overflow for type `short`
fail_compilation/fail109.d(65): Error: cannot check `fail109.B.end` value for overflow
    end
    ^
fail_compilation/fail109.d(65): Error: comparison between different enumeration types `B` and `C`; If this behavior is intended consider using `std.conv.asOriginalType`
    end
    ^
fail_compilation/fail109.d(65): Error: enum member `fail109.B.end` initialization with `B.start+1` causes overflow for type `C`
    end
    ^
fail_compilation/fail109.d(77): Error: enum member `fail109.RegValueType1a.Unknown` is forward referenced looking for `.max`
    Unknown = DWORD.max,
    ^
fail_compilation/fail109.d(84): Error: enum member `fail109.RegValueType1b.Unknown` is forward referenced looking for `.max`
    Unknown = DWORD.max,
    ^
fail_compilation/fail109.d(89): Error: enum member `fail109.RegValueType2a.Unknown` is forward referenced looking for `.min`
    Unknown = DWORD.min,
    ^
fail_compilation/fail109.d(96): Error: enum member `fail109.RegValueType2b.Unknown` is forward referenced looking for `.min`
    Unknown = DWORD.min,
    ^
fail_compilation/fail109.d(105): Error: enum member `fail109.d` initialization with `__anonymous.c+1` causes overflow for type `Q`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=11088
// https://issues.dlang.org/show_bug.cgi?id=14950
// https://issues.dlang.org/show_bug.cgi?id=11849

enum Bool : bool
{
    False,
    True,
    Unknown
}

enum E
{
    A = int.max,
    B
}

enum E1 : short
{
    A = short.max,
    B
}

enum C
{
    start,
    end
}
enum B
{
    start = C.end,
    end
}

alias DWORD = uint;

enum : DWORD
{
    REG_DWORD = 4
}

enum RegValueType1a : DWORD
{
    Unknown = DWORD.max,
    DWORD = REG_DWORD,
}

enum RegValueType1b : DWORD
{
    DWORD = REG_DWORD,
    Unknown = DWORD.max,
}

enum RegValueType2a : DWORD
{
    Unknown = DWORD.min,
    DWORD = REG_DWORD,
}

enum RegValueType2b : DWORD
{
    DWORD = REG_DWORD,
    Unknown = DWORD.min,
}

struct Q {
	enum max = Q();
}

enum {
	c = Q(),
	d
}
