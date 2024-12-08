/*
TEST_OUTPUT:
---
fail_compilation/b15069.d(19): Error: template instance `T!int` `T` is not a template declaration, it is a alias
	T!(int) var;
 ^
fail_compilation/b15069.d(14): Error: template instance `b15069.Stuff!(Thing!float)` error instantiating
	Stuff!(Thing!(float)) s;
 ^
---
*/
void main()
{
	Stuff!(Thing!(float)) s;
}

struct Stuff(T)
{
	T!(int) var;
}

struct Thing(T)
{
	T varling;
}
