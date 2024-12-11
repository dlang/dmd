/*
TEST_OUTPUT:
---
fail_compilation/fail60.d(16): Error: cannot construct nested class `B` because no implicit `this` reference to outer class `A` is available
 B b=new B;
     ^
---
*/
class A
{
 class B
 {

 }

 B b=new B;
}
