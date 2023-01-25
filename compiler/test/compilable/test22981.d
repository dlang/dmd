// https://issues.dlang.org/show_bug.cgi?id=22981
mixin ("enum E1 {", S1.attr, "}");

struct S1
{
    E1 e;
    enum attr = "a";
}

////

template E2()
{
    mixin ("enum E2 {", S2.attr, "}");
}

struct S2
{
    E2!() e;
    enum attr = "a";
}

////

template E3_()
{
	mixin ("enum E3_ {", S3.attr, "}");
}

alias E3 = E3_!();

struct S3
{
    E3 e;
    enum attr = "a";
}

////

template E4_()
{
	mixin ("enum E4_ {", S4.attr, "}");
}

struct S4
{
    alias E4 = E4_!();
    E4 e;
    enum attr = "a";
}

////

mixin ("enum E5 {", __traits(getAttributes, S5)[0], "}");

@("a")
struct S5
{
    E5 e;
}

////

mixin ("enum E6 {", __traits(getAttributes, S6)[0], "}");

@(S6.a)
struct S6
{
    E6 e;
    enum a = "dfgdf";
}
