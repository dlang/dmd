// https://issues.dlang.org/show_bug.cgi?id=17512

struct A
{
    int _value;

    bool _hasValue;

    auto ref getOr(int alternativeValue)
    {
        return _hasValue ? _value : alternativeValue;
    }
}

A a;
