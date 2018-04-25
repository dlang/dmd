/*
TEST_OUTPUT:
---
fail_compilation/test11970.d-mixin-98(98): Error: `bool_ = bool_` has no effect
fail_compilation/test11970.d-mixin-98(98): Error: `bool_sa = bool_sa` has no effect
fail_compilation/test11970.d-mixin-98(98): Error: `bool_da = bool_da` has no effect
fail_compilation/test11970.d-mixin-99(99): Error: `ubyte_ = ubyte_` has no effect
fail_compilation/test11970.d-mixin-99(99): Error: `ubyte_sa = ubyte_sa` has no effect
fail_compilation/test11970.d-mixin-99(99): Error: `ubyte_da = ubyte_da` has no effect
fail_compilation/test11970.d-mixin-100(100): Error: `byte_ = byte_` has no effect
fail_compilation/test11970.d-mixin-100(100): Error: `byte_sa = byte_sa` has no effect
fail_compilation/test11970.d-mixin-100(100): Error: `byte_da = byte_da` has no effect
fail_compilation/test11970.d-mixin-101(101): Error: `char_ = char_` has no effect
fail_compilation/test11970.d-mixin-101(101): Error: `char_sa = char_sa` has no effect
fail_compilation/test11970.d-mixin-101(101): Error: `char_da = char_da` has no effect
fail_compilation/test11970.d-mixin-102(102): Error: `wchar_ = wchar_` has no effect
fail_compilation/test11970.d-mixin-102(102): Error: `wchar_sa = wchar_sa` has no effect
fail_compilation/test11970.d-mixin-102(102): Error: `wchar_da = wchar_da` has no effect
fail_compilation/test11970.d-mixin-103(103): Error: `dchar_ = dchar_` has no effect
fail_compilation/test11970.d-mixin-103(103): Error: `dchar_sa = dchar_sa` has no effect
fail_compilation/test11970.d-mixin-103(103): Error: `dchar_da = dchar_da` has no effect
fail_compilation/test11970.d-mixin-104(104): Error: `ushort_ = ushort_` has no effect
fail_compilation/test11970.d-mixin-104(104): Error: `ushort_sa = ushort_sa` has no effect
fail_compilation/test11970.d-mixin-104(104): Error: `ushort_da = ushort_da` has no effect
fail_compilation/test11970.d-mixin-105(105): Error: `short_ = short_` has no effect
fail_compilation/test11970.d-mixin-105(105): Error: `short_sa = short_sa` has no effect
fail_compilation/test11970.d-mixin-105(105): Error: `short_da = short_da` has no effect
fail_compilation/test11970.d-mixin-106(106): Error: `uint_ = uint_` has no effect
fail_compilation/test11970.d-mixin-106(106): Error: `uint_sa = uint_sa` has no effect
fail_compilation/test11970.d-mixin-106(106): Error: `uint_da = uint_da` has no effect
fail_compilation/test11970.d-mixin-107(107): Error: `int_ = int_` has no effect
fail_compilation/test11970.d-mixin-107(107): Error: `int_sa = int_sa` has no effect
fail_compilation/test11970.d-mixin-107(107): Error: `int_da = int_da` has no effect
fail_compilation/test11970.d-mixin-108(108): Error: `ulong_ = ulong_` has no effect
fail_compilation/test11970.d-mixin-108(108): Error: `ulong_sa = ulong_sa` has no effect
fail_compilation/test11970.d-mixin-108(108): Error: `ulong_da = ulong_da` has no effect
fail_compilation/test11970.d-mixin-109(109): Error: `long_ = long_` has no effect
fail_compilation/test11970.d-mixin-109(109): Error: `long_sa = long_sa` has no effect
fail_compilation/test11970.d-mixin-109(109): Error: `long_da = long_da` has no effect
fail_compilation/test11970.d-mixin-110(110): Error: `float_ = float_` has no effect
fail_compilation/test11970.d-mixin-110(110): Error: `float_sa = float_sa` has no effect
fail_compilation/test11970.d-mixin-110(110): Error: `float_da = float_da` has no effect
fail_compilation/test11970.d-mixin-111(111): Error: `double_ = double_` has no effect
fail_compilation/test11970.d-mixin-111(111): Error: `double_sa = double_sa` has no effect
fail_compilation/test11970.d-mixin-111(111): Error: `double_da = double_da` has no effect
fail_compilation/test11970.d-mixin-112(112): Error: `real_ = real_` has no effect
fail_compilation/test11970.d-mixin-112(112): Error: `real_sa = real_sa` has no effect
fail_compilation/test11970.d-mixin-112(112): Error: `real_da = real_da` has no effect
fail_compilation/test11970.d-mixin-113(113): Error: `string_ = string_` has no effect
fail_compilation/test11970.d-mixin-113(113): Error: `string_sa = string_sa` has no effect
fail_compilation/test11970.d-mixin-113(113): Error: `string_da = string_da` has no effect
fail_compilation/test11970.d-mixin-115(115): Error: `S_ = S_` has no effect
fail_compilation/test11970.d-mixin-115(115): Error: `S_sa = S_sa` has no effect
fail_compilation/test11970.d-mixin-115(115): Error: `S_da = S_da` has no effect
fail_compilation/test11970.d-mixin-116(116): Error: `C_ = C_` has no effect
fail_compilation/test11970.d-mixin-116(116): Error: `C_sa = C_sa` has no effect
fail_compilation/test11970.d-mixin-116(116): Error: `C_da = C_da` has no effect
fail_compilation/test11970.d-mixin-117(117): Error: `E_ = E_` has no effect
fail_compilation/test11970.d-mixin-117(117): Error: `E_sa = E_sa` has no effect
fail_compilation/test11970.d-mixin-117(117): Error: `E_da = E_da` has no effect
---
*/

// https://issues.dlang.org/show_bug.cgi?id=11970

template testType(T)
{
    // example: byte byte_; byte_ = byte_;
    enum id = T.stringof ~ "_";
    enum testType = T.stringof ~ " " ~ id ~ "; " ~ id ~ " = " ~ id ~ ";";
}

template testStaticArray(T)
{
    // example: byte[2] byte_sa; byte_sa = byte_sa;
    enum id = T.stringof ~ "_sa";
    enum testStaticArray = T.stringof ~ "[2] " ~ id ~ "; " ~ id ~ " = " ~ id ~ ";";
}

template testDynamicArray(T)
{
    // example: byte[] byte_da; byte_da = byte_da;
    enum id = T.stringof ~ "_da";
    enum testDynamicArray = T.stringof ~ "[] " ~ id ~ "; " ~ id ~ " = " ~ id ~ ";";
}

template test(T)
{
    enum test = testType!T ~ testStaticArray!T ~ testDynamicArray!T;
}

struct S { }
class C { }
enum E { e0 }

void test11970()
{
    mixin(test!bool);
    mixin(test!ubyte);
    mixin(test!byte);
    mixin(test!char);
    mixin(test!wchar);
    mixin(test!dchar);
    mixin(test!ushort);
    mixin(test!short);
    mixin(test!uint);
    mixin(test!int);
    mixin(test!ulong);
    mixin(test!long);
    mixin(test!float);
    mixin(test!double);
    mixin(test!real);
    mixin(test!string);

    mixin(test!S);
    mixin(test!C);
    mixin(test!E);
}
