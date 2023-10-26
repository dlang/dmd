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
	alias SQLINTERVAL = enum SQLINTERVAL;
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
