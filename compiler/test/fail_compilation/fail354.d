/*
TEST_OUTPUT:
---
fail_compilation/fail354.d(15): Error: template instance `T!N` template `T` is not defined
    this(T!N) { }
         ^
fail_compilation/fail354.d(17): Error: template instance `fail354.S!1` error instantiating
alias S!1 M;
      ^
---
*/

struct S(int N)
{
    this(T!N) { }
}
alias S!1 M;
