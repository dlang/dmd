void foo()
{
	import std.stdio: writeln, write,;
	write("foo");
}

void bar()
{
	import std.stdio: writeln,;
	writeln("bar");
}

void foobar()
{
	import std.stdio: ;
}

int main() {
	foobar();
	foo();
	bar();
	return 1;
}