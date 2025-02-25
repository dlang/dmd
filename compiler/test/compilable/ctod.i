/*
PERMUTE_ARGS:
REQUIRED_ARGS: -Hf=${RESULTS_DIR}/compilable/ctod.di
OUTPUT_FILES: ${RESULTS_DIR}/compilable/ctod.di

TEST_OUTPUT:
---
=== ${RESULTS_DIR}/compilable/ctod.di
// D import file generated from 'compilable/ctod.i'
extern (C)
{
	uint equ(double x, double y);
	enum SQLINTERVAL
	{
		SQL_IS_YEAR = 1,
		SQL_IS_MONTH = 2,
	}
	alias SQL_IS_YEAR = SQLINTERVAL.SQL_IS_YEAR;
	alias SQL_IS_MONTH = SQLINTERVAL.SQL_IS_MONTH;
	struct Foo
	{
		int x = void;
	}
	Foo abc();
	union S
	{
		int x = void;
	}
	alias T = S;
	enum
	{
		A,
	}
	struct S24326
	{
		int x = void;
	}
	const(S24326) fun(int y);
	struct foo
	{
		int x = void;
	}
	alias weird = int[(cast(foo*)cast(void*)0).x.sizeof];
	alias ULONG = ulong;
	alias ULONG_Deluxe = ulong;
	alias ULONG_PTR = ulong*;
	alias Callback = void* function();
	struct Test
	{
		ULONG_Deluxe d = void;
		ULONG_Deluxe* p = void;
		ULONG_PTR q = void;
		Callback cb = void;
	}
	extern __gshared int[cast(ULONG)3] arr;
	/+enum int __DATE__ = 1+/;
	/+enum int __TIME__ = 1+/;
	/+enum int __TIMESTAMP__ = 1+/;
	/+enum int __EOF__ = 1+/;
	/+enum int __VENDOR__ = 1+/;
	enum int DEF = 123;
	enum int SQL_DRIVER_STMT_ATTR_BASE = 16384;
	enum int ABC = 64;
}
---
 */


unsigned equ(double x, double y)
{
    return *(long long *)&x == *(long long *)&y;
}

typedef enum
{
    SQL_IS_YEAR = 1,
    SQL_IS_MONTH = 2
} SQLINTERVAL;

struct Foo {
    int x;
};

struct Foo abc(void);

// https://issues.dlang.org/show_bug.cgi?id=24276

union S
{
     int x;
};
typedef S T;

// https://issues.dlang.org/show_bug.cgi?id=24200

#define __DATE__ 1
#define __TIME__  1
#define __TIMESTAMP__  1
#define __EOF__  1
#define __VENDOR__  1

// https://issues.dlang.org/show_bug.cgi?id=24326
enum { A };

// https://issues.dlang.org/show_bug.cgi?id=24670
struct S24326 { int x; };
const struct S24326 fun(int y);

// https://issues.dlang.org/show_bug.cgi?id=24375
struct foo {
    int x;
};
typedef int weird[sizeof(((struct foo *)((void*)0))->x)];

// https://github.com/dlang/dmd/issues/20889
typedef unsigned long long ULONG;
typedef ULONG ULONG_Deluxe;
typedef ULONG_Deluxe *ULONG_PTR;
typedef void *(*Callback)();

struct Test
{
	ULONG_Deluxe d;
	ULONG_Deluxe *p;
	ULONG_PTR q;
	Callback cb;
};

int arr[(ULONG) 3];

#define DEF 123
#define SQL_DRIVER_STMT_ATTR_BASE   0x00004000  // 32-bit
#define ABC 64
