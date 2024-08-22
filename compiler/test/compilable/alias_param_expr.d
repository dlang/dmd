/*
TEST_OUTPUT:
---
A
B
---
*/

template Tpl(T, alias S = "" ~ T.stringof) {
	pragma(msg, S);
}
class A { }
class B { }
alias TA = Tpl!A;
alias TB = Tpl!B;
