/* TEST_OUTPUT:
---
fail_compilation/fix22263.c(108): Error: function `fix22263.f3` conflicts with function `fix22263.f3` at fail_compilation/fix22263.c(107)
fail_compilation/fix22263.c(127): Error: variable `fix22263.x4` conflicts with variable `fix22263.x4` at fail_compilation/fix22263.c(126)
fail_compilation/fix22263.c(133): Error: variable `fix22263.x6` conflicts with variable `fix22263.x6` at fail_compilation/fix22263.c(132)
---
 */

// https://issues.dlang.org/show_bug.cgi?id=22263

#line 100

extern void f1(int);
void f1(int a) { }

static void f2(int);
static void f2(int a) { }

static void f3(int) { }
static void f3(int a) { }

void foo()
{
    f1(42);
    f2(42);
    f3(42);
}

extern const int x1;
const int x1 = 1;

int x2 = 2;
extern int x2;

static int x3;
static int x3 = 3;

static int x4;
int x4;

int x5;
int x5;

int x6 = 6;
int x6 = 6;

