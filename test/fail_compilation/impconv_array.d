// https://issues.dlang.org/show_bug.cgi?id=1654

/*
  TEST_OUTPUT:
  ---
  fail_compilation/impconv_array.d(38): Error: undefined identifier `f`
  ---
*/

alias AliasSeq(TList...) = TList;

@safe pure:

unittest
{
    alias M = char[];
    alias C = const(char)[];
    alias I = immutable(char)[];
    static foreach (X; AliasSeq!(M, C, I))
        static foreach (Y; AliasSeq!(M, C, I))
            static foreach (Z; AliasSeq!(M, C, I))
            {
                {
                    X x;
                    Y y;
                    I z = x ~ y;
                }
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
