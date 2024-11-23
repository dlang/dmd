/*
TEST_OUTPUT:
---
fail_compilation/disable.d(76): Error: function `disable.DisabledOpAssign.opAssign` cannot be used because it is annotated with `@disable`
    o = DisabledOpAssign();
      ^
fail_compilation/disable.d(79): Error: function `disable.DisabledPostblit.opAssign` cannot be used because it is annotated with `@disable`
    p = DisabledPostblit();
      ^
fail_compilation/disable.d(82): Error: function `disable.HasDtor.opAssign` cannot be used because it is annotated with `@disable`
    d = HasDtor();
      ^
fail_compilation/disable.d(86): Error: generated function `disable.Nested!(DisabledOpAssign).Nested.opAssign` cannot be used because it is annotated with `@disable`
    no = Nested!(DisabledOpAssign)();
       ^
fail_compilation/disable.d(89): Error: generated function `disable.Nested!(DisabledPostblit).Nested.opAssign` cannot be used because it is annotated with `@disable`
    np = Nested!(DisabledPostblit)();
       ^
fail_compilation/disable.d(92): Error: generated function `disable.Nested!(HasDtor).Nested.opAssign` cannot be used because it is annotated with `@disable`
    nd = Nested!(HasDtor)();
       ^
fail_compilation/disable.d(96): Error: generated function `disable.NestedDtor!(DisabledOpAssign).NestedDtor.opAssign` cannot be used because it is annotated with `@disable`
    ndo = NestedDtor!(DisabledOpAssign)();
        ^
fail_compilation/disable.d(99): Error: generated function `disable.NestedDtor!(DisabledPostblit).NestedDtor.opAssign` cannot be used because it is annotated with `@disable`
    ndp = NestedDtor!(DisabledPostblit)();
        ^
fail_compilation/disable.d(102): Error: generated function `disable.NestedDtor!(HasDtor).NestedDtor.opAssign` cannot be used because it is annotated with `@disable`
    ndd = NestedDtor!(HasDtor)();
        ^
fail_compilation/disable.d(104): Error: enum member `disable.Enum1.value` cannot be used because it is annotated with `@disable`
    auto v1 = Enum1.value;
              ^
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
