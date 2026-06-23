struct A
{
    mixin template Foo() {}
}

alias AliasSeq(A...) = A;

alias thing = AliasSeq!(A);

mixin thing[0].Foo;
