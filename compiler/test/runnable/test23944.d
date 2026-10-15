// https://github.com/dlang/dmd/issues/23944
// typeid(C).name is the fully qualified name in CTFE, as it is at runtime

module test23944;

class C {}

struct S
{
    class Nested {}
}

static assert(typeid(C).name == "test23944.C");
static assert(typeid(S.Nested).name == "test23944.S.Nested");
static assert(typeid(TypeInfo_Class).name == "TypeInfo_Class");

void main()
{
    assert(typeid(C).name == "test23944.C");
    assert(typeid(S.Nested).name == "test23944.S.Nested");
    assert(typeid(TypeInfo_Class).name == "TypeInfo_Class");
}
