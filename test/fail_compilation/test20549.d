/*
TEST_OUTPUT:
----
fail_compilation/test20549.d(13): Error: variable `test.__a_field_0` variables cannot be of type `void`
fail_compilation/test20549.d(13): Error: cannot interpret `module test` at compile time
----
*/

module test;

alias AliasSeq(T...) = T;

enum a = AliasSeq!test;
