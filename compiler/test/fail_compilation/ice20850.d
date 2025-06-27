/*
TEST_OUTPUT:
---
fail_compilation/ice20850.d(26): Error: alias `fromEnum` is not a variable
fail_compilation/ice20850.d(27): Error: alias `fromEnum` is not a variable
fail_compilation/ice20850.d(28): Error: alias `fromStruct1` is not a variable
fail_compilation/ice20850.d(29): Error: alias `fromStruct1` is not a variable
fail_compilation/ice20850.d(30): Error: alias `fromStruct2` is not a variable
fail_compilation/ice20850.d(31): Error: alias `fromStruct2` is not a variable
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
