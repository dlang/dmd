/+
REQUIRED_ARGS: -mangle-prefix=.:_kek_ -mangle-prefix=runnable/mangle_prefix.d:_mypackage_._v2_0_
TEST_OUTPUT:
---
_D11_mypackage_6_v2_0_13mangle_prefix3_c_CQBoQBeQBa9_MyClass_
_D11_mypackage_6_v2_0_13mangle_prefix3_s_SQBoQBeQBa10_MyStruct_
_D11_mypackage_6_v2_0_13mangle_prefix4_ms_SQBpQBfQBb10_MyStruct_
_D11_mypackage_6_v2_0_13mangle_prefix4_pi_f
_D11_mypackage_6_v2_0_13mangle_prefix5_foo_FiCQBsQBiQBe9_MyClass_SQCmQCcQBy10_MyStruct_Zi
_D11_mypackage_6_v2_0_13mangle_prefix13_MyInterface_5_bar_MFZl
_D11_mypackage_6_v2_0_13mangle_prefix9_MyClass_5_bar_MFZl
_D11_mypackage_6_v2_0_13mangle_prefix9_MyClass_5_kek_MFZl
_D11_mypackage_6_v2_0_13mangle_prefix9_MyClass_8toStringMFZAya
_D11_mypackage_6_v2_0_13mangle_prefix10_MyStruct_3_d_d
_D11_mypackage_6_v2_0_13mangle_prefix4_ip_S3std8typecons__T5TupleThThThThZQp
---
+/
module mangle_prefix;

shared static this()
{
    _s_ = _MyStruct_(_pi_ / 2);
}

static this()
{
    _ms_ = _MyStruct_(_pi_);
}

__gshared _MyClass_ _c_ = new _MyClass_;
__gshared _MyStruct_ _s_;
_MyStruct_ _ms_;

float _pi_ = 3.14f;

int _foo_(int x, _MyClass_ c, _MyStruct_ s)
{
    return x * x;
}

interface _MyInterface_
{
    long _bar_();
}

class _MyClass_ : _MyInterface_
{
    long _bar_()
    {
        return 5;
    }

    final long _kek_()
    {
        return 10;
    }

    override string toString()
    {
        return "MyClass";
    }
}

struct _MyStruct_
{
    double _d_;
}

import std.typecons;

Tuple!(ubyte, ubyte, ubyte, ubyte) _ip_;

pragma(msg, _c_.mangleof);
pragma(msg, _s_.mangleof);
pragma(msg, _ms_.mangleof);
pragma(msg, _pi_.mangleof);
pragma(msg, _foo_.mangleof);
pragma(msg, _MyInterface_._bar_.mangleof);
pragma(msg, _MyClass_._bar_.mangleof);
pragma(msg, _MyClass_._kek_.mangleof);
pragma(msg, _MyClass_.toString.mangleof);
pragma(msg, _MyStruct_._d_.mangleof);
pragma(msg, _ip_.mangleof);

void main()
{
    _c_ = cast(_MyClass_)Object.factory("mangle_prefix._MyClass_");
    assert(_c_ !is null);
    assert(_c_._bar_ == 5);
    assert(_s_ == _MyStruct_(_pi_ / 2));
    assert(_ms_ == _MyStruct_(_pi_));
}
