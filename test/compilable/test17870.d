alias AliasSeq(T...) = T;

class A
{
    int a = 1;
}

class B : A
{
    int b = 2;
    alias tup = AliasSeq!(b, a);
}

void main()
{
    static const ins = new B;
    static assert(&ins.tup[0] == &ins.b);
    static assert(&ins.tup[1] == &ins.a);
    static assert(ins.tup == AliasSeq!(2,1));
}
