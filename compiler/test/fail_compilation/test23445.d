/* REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test23445.d(105): Error: cannot make delegate from `__lambda2` because it returns `p` from outer `foo1`
fail_compilation/test23445.d(117): Error: cannot make delegate from `nested` because it returns `p` from outer `foo2`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=23445

#line 100

int global;

int* foo1(scope int* p)@safe
{
    auto dg=(return scope int* q)@safe return scope{
        return p;
    };
    return dg(&global);
}

int* foo2(scope int* p)@safe
{
    int* nested(return scope int* q)@safe return scope
    {
        return p;
    }
    auto dg = &nested;
    return dg(&global);
}

struct S
{
    char* p;

    char* parseType() return scope pure @safe
    {
	char* parseBackrefType() pure @safe
	{
	    char* foo() { return p; }
            auto dg = &foo;
	    return dg();
	}
	return p;
    }
}

struct T
{
    char* p;

    char* parseType() return scope pure @safe
    {
	char* parseBackrefType(scope char* delegate() pure @safe parseDg) pure @safe
	{
	    char* foo() { return parseType(); }
            auto dg = &foo;
	    return parseBackrefType( dg );
	}
	return p;
    }
}
