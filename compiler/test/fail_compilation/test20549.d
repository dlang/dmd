/*
TEST_OUTPUT:
----
fail_compilation/test20549.d(14): Error: variable `test.__a_field_0` - variables cannot be of type `void`
enum a = AliasSeq!test;
     ^
----
*/

module test;

alias AliasSeq(T...) = T;

enum a = AliasSeq!test;
