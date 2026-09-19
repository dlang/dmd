struct A
{
    mixin template Foo() {}
}

alias AliasSeq(A...) = A;

alias thing = AliasSeq!(A);

mixin thing[0].Foo;
mixin typeof(thing)[0].Foo;

mixin template M() {}
mixin mixin("M");
mixin __traits(getMember, A, "Foo");
