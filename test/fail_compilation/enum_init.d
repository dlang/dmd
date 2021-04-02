/*
https://issues.dlang.org/show_bug.cgi?id=8511

TEST_OUTPUT:
---
fail_compilation/enum_init.d(5): Error: type `SQRTMAX` has no value
---
*/
#line 1

real hypot()
{
    enum SQRTMAX;
    SQRTMAX/2;
}

/*
https://issues.dlang.org/show_bug.cgi?id=21785

TEST_OUTPUT:
---
fail_compilation/enum_init.d(106): Error: enum `enum_init.NoBase` is opaque and has no default initializer
---
*/
#line 100

enum NoBase;

void fooNB()
{
	NoBase nbv = void;
	NoBase nb;
}

/*
https://issues.dlang.org/show_bug.cgi?id=21785

TEST_OUTPUT:
---
fail_compilation/enum_init.d(206): Error: enum `enum_init.Xobj` is opaque and has no default initializer
---
*/
#line 200

enum Xobj : void*;

void main()
{
	Xobj vv = void;
	Xobj var;
}


/*
https://issues.dlang.org/show_bug.cgi?id=21785

TEST_OUTPUT:
---
fail_compilation/enum_init.d(306): Error: variable `enum_init.fooOB.ob` no definition of struct `S`
fail_compilation/enum_init.d(302):        required by type `OpaqueBase`
---
*/
#line 300

struct S;
enum OpaqueBase : S;

void fooOB()
{
	OpaqueBase ob;
}

/*
TEST_OUTPUT:
---
fail_compilation/enum_init.d(405): Error: enum `enum_init.forwardRef.Foo` forward reference of `Foo.init`
---
*/
#line 400

void forwardRef()
{
    enum Foo
    {
        a = Foo.init
    }
}
