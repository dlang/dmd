import std.stdio;
struct S {};
alias S T;
//alias int T;

T fun() { T t; return t; }
const(T) constfun() { T t; return t; }
void gun(const ref T t) { writeln("gun(const ref T)"); }
void gun(ref T t) { writeln("gun(ref T)"); }
void gun(const T t) { writeln("gun(const T)"); }
void gun(T t) { writeln("gun(T)"); }
void main()
{
	T t;
	const T constt;
	gun(constt);
	gun(t);
    gun(constfun);
    gun(fun);
}
