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
	/+enum int __DATE__ = 1+/;
	/+enum int __TIME__ = 1+/;
	/+enum int __TIMESTAMP__ = 1+/;
	/+enum int __EOF__ = 1+/;
	/+enum int __VENDOR__ = 1+/;
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
