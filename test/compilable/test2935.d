// https://issues.dlang.org/show_bug.cgi?id=2935

struct S2935
{
   int z;
   this(int a) { z = a; }
}

void test2935(S2935 a = S2935(1)) { }

void main()
{
    test2935();
}
