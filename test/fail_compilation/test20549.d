module test;

alias AliasSeq(T...) = T;

enum a = AliasSeq!test;
