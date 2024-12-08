/* TEST_OUTPUT:
REQUIRED_ARGS: -preview=dip1000
---
fail_compilation/test15191.d(44): Error: returning `&identity(x)` escapes a reference to local variable `x`
	return &identity(x);
        ^
fail_compilation/test15191.d(50): Error: returning `&identityPtr(x)` escapes a reference to local variable `x`
	return &identityPtr(x);
        ^
fail_compilation/test15191.d(56): Error: returning `&identityPtr(x)` escapes a reference to local variable `x`
	return &identityPtr(x);
        ^
fail_compilation/test15191.d(77): Error: cannot take address of `scope` variable `x` since `scope` applies to first indirection only
	auto y = identityArr(x)[]; // check transitive scope in assignment
      ^
fail_compilation/test15191.d(79): Error: cannot take address of `scope` variable `x` since `scope` applies to first indirection only
	return identityArr(x)[]; // check transitive scope in return statement
                      ^
---
*/

// Test taking the address of a `ref return` using & and [] operators
// https://issues.dlang.org/show_bug.cgi?id=15191
// https://issues.dlang.org/show_bug.cgi?id=22519
// https://issues.dlang.org/show_bug.cgi?id=22539

@safe:
ref int foo(return ref int s)
{
    return s;
}

int* bar(return ref int s)
{
    return &foo(s);
}

ref int identity(ref return int x) {return x;}
ref int* identityPtr(ref return int* x) {return x;}

int* addrOfRefEscape()
{
	int x;
	return &identity(x);
}

int** addrOfRefSystem() @system
{
	int* x;
	return &identityPtr(x);
}

int** addrOfRefTransitive()
{
	int* x;
	return &identityPtr(x);
}

int gInt;
ref int getGlobalInt() {return gInt;}

int* addrOfRefGlobal()
{
	return &getGlobalInt();
}

// Slice:
ref int*[1] identityArr(return ref scope int*[1] x)
{
	return x;
}

int*[] sliceOfRefEscape()
{
	int stackVar = 0xFF;
	scope int*[1] x = [&stackVar];
	auto y = identityArr(x)[]; // check transitive scope in assignment
	cast(void) y;
	return identityArr(x)[]; // check transitive scope in return statement
}

// https://issues.dlang.org/show_bug.cgi?id=23079
int** p;

ref int* get() @safe
{
    return *p;
}

int** g1() @safe
{
    return &get();
}
