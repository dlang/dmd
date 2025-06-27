/*
TEST_OUTPUT:
---
fail_compilation/ice20850.d(26): Error: type `A()` is not an expression
fail_compilation/ice20850.d(27): Error: type `A()` is not an expression
fail_compilation/ice20850.d(28): Error: type `S1()` is not an expression
fail_compilation/ice20850.d(29): Error: type `S1()` is not an expression
fail_compilation/ice20850.d(30): Error: type `S2()` is not an expression
fail_compilation/ice20850.d(31): Error: type `S2()` is not an expression
---
*/
enum A;
alias fromEnum = A();

struct S1 {}
alias fromStruct1 = S1();

struct S2
{
    this()(){}
}
alias fromStruct2 = S2();

void main()
{
    fromEnum(0);
    fromEnum();
    fromStruct1(0);
    fromStruct1();
    fromStruct2(0);
    fromStruct2();
}
