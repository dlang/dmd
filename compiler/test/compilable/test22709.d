// https://github.com/dlang/dmd/issues/22709
// extern(C++) destructor in base class should not be flagged as hidden

extern(C++):
class A
{
    ~this();
}
class B : A
{
}
class C : B
{
    ~this();
}
