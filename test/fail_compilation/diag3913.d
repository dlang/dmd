/*
TEST_OUTPUT:
---
fail_compilation/diag3913.d(8): Error: no property 'b' for type 'En1'
fail_compilation/diag3913.d(9): Error: no property 'b' for type 'En2'
fail_compilation/diag3913.d(10): Error: no property 'b' for type 'En3'
---
*/

#line 1
enum En1 { a }
enum En2 : En1 { c = En1.a }
struct S { enum a = 1; }
enum En3 : S { a = S() }

void main()
{
    auto e1 = En1.b;
    auto e2 = En2.b;
    auto e3 = En3.b;
}
