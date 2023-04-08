// https://issues.dlang.org/show_bug.cgi?id=16486
// Alias Template IFTI
module testatifti;

struct TempT(T)
{

}

alias AliasT(U) = TempT!U;
alias AliasPT(U) = TempT!(U*);

void fooAliasT(U)(AliasT!U v)
{
    static assert(is(U == float));
    static assert(is(typeof(v) == TempT!(float)));
}

void fooAliasPT(U)(AliasPT!(U) v)
{
    static assert(is(U == float));
    static assert(is(typeof(v) == TempT!(float*)));
}

void pfooAliasPT(U)(AliasPT!(U*) v)
{
    static assert(is(U == float));
    static assert(is(typeof(v) == TempT!(float**)));
}

struct TempVar(T...)
{

}

alias AliasVar(T, U...) = TempVar!(T, U);

void fooAliasVar(U...)(AliasVar!U v)
{
    static assert(is(U[0] == float));
    static assert(is(U[1] == int));
    static assert(is(U[2] == char));
    static assert(is(U[3] == string));
}

struct TempDiverse(X, Y, size_t Z, alias W)
{
}

alias AliasDiverse(P, Q, alias R, size_t S) = TempDiverse!(Q, P, S, R);

void fooAliasDiverse(A, B, alias C, size_t D)(AliasDiverse!(B, A, C, D) v)
{
    static assert(is(A == string));
    static assert(is(B == char));
    static assert(C == 1);
    static assert(D == 12);
    static assert(is(typeof(v) == TempDiverse!(string, char, 12, 1)));
}

void fooAliasDiverse2(U)(AliasDiverse!(U, U, 1, 1) v)
{
    static assert(is(U == float));
}

struct Matrix(U, size_t M, size_t N)
{

}

alias Vector(U, size_t N) = Matrix!(U, N, 1);
alias Vector3(U) = Vector!(U, 3);

void normalize(U, size_t N)(ref Vector!(U, N) v)
{
}

Vector3!U cross(U)(Vector3!U a, Vector3!U b)
{
    return Vector3!U.init;
}

// a case grabbed from PR #9778
struct TestType(T, Q)
{
}

alias TestAliasA(A, B) = TestType!(A, B);
alias TestAlias(T, Q) = TestAliasA!(Q, T);
void test(X, Y)(TestAliasA!(X, Y) v)
{
}

void main()
{
    fooAliasT(AliasT!float());
    fooAliasPT(AliasPT!(float)());
    pfooAliasPT(AliasPT!(float*)());
    fooAliasVar(AliasVar!(float, int, char, string)());
    fooAliasDiverse(AliasDiverse!(char, string, 1, 12)());
    fooAliasDiverse2(AliasDiverse!(float, float, 1, 1)());
    static assert(is(Vector3!float == Vector3!U, U)); // !!!
    static assert(is(Vector!(float, 3) == Vector!(U, N), U, size_t N));

    Vector!(float, 10) v;
    normalize(v);

    Vector3!float vv = cross(Vector3!float(), Vector3!float());
    test(TestAlias!(float, char)());
}
