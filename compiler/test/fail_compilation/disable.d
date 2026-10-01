/*
TEST_OUTPUT:
---
fail_compilation/disable.d(56): Error: function `disable.DisabledOpAssign.opAssign` cannot be used because it is annotated with `@disable`
fail_compilation/disable.d(59): Error: function `disable.DisabledPostblit.opAssign` cannot be used because it is annotated with `@disable`
fail_compilation/disable.d(62): Error: function `disable.HasDtor.opAssign` cannot be used because it is annotated with `@disable`
fail_compilation/disable.d(66): Error: struct `disable.Nested!(DisabledOpAssign)` is not assignable because field `b` is not assignable
fail_compilation/disable.d(69): Error: struct `disable.Nested!(DisabledPostblit)` is not assignable because field `b` is not assignable
fail_compilation/disable.d(72): Error: struct `disable.Nested!(HasDtor)` is not assignable because field `b` is not assignable
fail_compilation/disable.d(76): Error: struct `disable.NestedDtor!(DisabledOpAssign)` is not assignable because field `b` is not assignable
fail_compilation/disable.d(79): Error: struct `disable.NestedDtor!(DisabledPostblit)` is not assignable because field `b` is not assignable
fail_compilation/disable.d(82): Error: struct `disable.NestedDtor!(HasDtor)` is not assignable because field `b` is not assignable
fail_compilation/disable.d(84): Error: enum member `disable.Enum1.value` cannot be used because it is annotated with `@disable`
---
 */
struct DisabledOpAssign {
    int x;
    @disable void opAssign(const DisabledOpAssign);
}

struct DisabledPostblit {
    int x;
    @disable void opAssign(const DisabledPostblit);
    // Doesn't require opAssign
    @disable this(this);
}

struct HasDtor {
    int x;
    @disable void opAssign(const HasDtor);
    ~this() {} // Makes opAssign mandatory
}


struct Nested (T)
{
    T b;
}

struct NestedDtor (T)
{
    T b;

    // Requires an identity opAssign
    ~this() {}
}

enum Enum1
{
    @disable value
}

void main ()
{
    DisabledOpAssign o;
    o = DisabledOpAssign();

    DisabledPostblit p;
    p = DisabledPostblit();

    HasDtor d;
    d = HasDtor();


    Nested!(DisabledOpAssign) no;
    no = Nested!(DisabledOpAssign)();

    Nested!(DisabledPostblit) np;
    np = Nested!(DisabledPostblit)();

    Nested!(HasDtor) nd;
    nd = Nested!(HasDtor)();


    NestedDtor!(DisabledOpAssign) ndo;
    ndo = NestedDtor!(DisabledOpAssign)();

    NestedDtor!(DisabledPostblit) ndp;
    ndp = NestedDtor!(DisabledPostblit)();

    NestedDtor!(HasDtor) ndd;
    ndd = NestedDtor!(HasDtor)();

    auto v1 = Enum1.value;
}
