/*
REQUIRED_ARGS: -preview=typefunctions
*/

alias type = __type__;

string fqn_type(type T)
{
    string result = __traits(identifier, T);
    type P = __traits(parent, T);
    bool good = is(P);
    while(good)
    {
        result = __traits(identifier, P) ~ "." ~ result;
        P = __traits(parent, P);
        good = is(P);
    }
    return result;
}

typeof(F(T[0]))[] map(alias F, T)(T[] args...)
{
    typeof(return) result;
    // result.length = args.length;
    foreach(i, a;args)
    {
        result ~= F(a);
    }
    return result;
}

struct S1_0 { struct S2 { struct S3 {} } }
struct S1_1 { struct S2 { struct S3 {struct S4 {} } } }
struct S1_2 { struct S2 { struct S3 {struct S4 {struct S5 {} } } } }
struct S1_3 { struct S2 { struct S3 {struct S4 {struct S5 { struct S6 {} } } } } }
struct S1_4 { struct S2 { struct S3 {struct S4 {struct S5 { struct S6 { struct S7 {} } } } } } }

static assert(map!(fqn_type, __type__) (
    S1_0,
    S1_0.S2,
    S1_0.S2.S3,
    S1_1.S2.S3.S4,
    S1_2.S2.S3.S4.S5,
    S1_3.S2.S3.S4.S5.S6,
    S1_4.S2.S3.S4.S5.S6.S7,
) == [ 
    "S1_0",
    "S1_0.S2",
    "S1_0.S2.S3",
    "S1_1.S2.S3.S4",
    "S1_2.S2.S3.S4.S5",
    "S1_3.S2.S3.S4.S5.S6",
    "S1_4.S2.S3.S4.S5.S6.S7"
]);

