/*
TEST_OUTPUT:
---
fail_compilation/test8793.d(4): Error: cannot implicitly convert expression (__lambda2) of type 'bool delegate(const(int) x) @system' to 'bool delegate(const(int)) pure'
fail_compilation/test8793.d(5): Error: cannot implicitly convert expression (__lambda4) of type 'bool delegate(const(int) x) @system' to 'bool delegate(const(int)) pure'
fail_compilation/test8793.d(7): Error: cannot implicitly convert expression (__lambda6) of type 'bool delegate(const(int) x) nothrow @safe' to 'bool delegate(const(int)) pure'
---
*/

#line 1
alias bool function(in int) pure Fp8793;
alias bool delegate(in int) pure Dg8793;

Dg8793 foo8793pfp2(const Fp8793* f) pure { return x => (*f)(x); }
Dg8793 foo8793pdg2(const Dg8793* f) pure { return x => (*f)(x); }

Dg8793 foo8793ptr2(const int* p) pure { return x => *p == x; }
