// https://issues.dlang.org/show_bug.cgi?id=1654

/*
  TEST_OUTPUT:
  ---
  fail_compilation/impconv_array.d(38): Error: undefined identifier `f`
CatExp::implicitConvTo(this=a ~ b, type=char[], t=string)
  ---
*/

alias AliasSeq(TList...) = TList;

void test1654_a()
{
    alias M = char[];
    alias C = const(char)[];
    alias I = immutable(char)[];

    foreach (X; AliasSeq!(M, C, I))
        foreach (Y; AliasSeq!(M, C, I))
            foreach (Z; AliasSeq!(M, C, I))
            {
                // pragma(msg, __FILE__, "(", __LINE__, ",1): Debug: X:", X, " Y:", Y, " Z:", Z);
                Z z1 = X.init ~ Y.init; // passes
                X x;
                Y y;
                // Z z2 = x ~ y;   // TODO: why does this fail?
            }
}

void test1654_b()
{
    alias S = char;
    {
        S[] a, b;
        immutable(S)[] c = a ~ b; // ok
    }
    f;
}
