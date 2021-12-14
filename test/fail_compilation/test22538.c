/* TEST_OUTPUT:
---
fail_compilation/test22538.c(111): Error: function `test22538.sun3` conflicts with function `test22538.sun3` at fail_compilation/test22538.c(110)
fail_compilation/test22538.c(114): Error: function `test22538.sun4` conflicts with function `test22538.sun4` at fail_compilation/test22538.c(113)
fail_compilation/test22538.c(117): Error: variable `test22538.rock1` conflicts with variable `test22538.rock1` at fail_compilation/test22538.c(116)
fail_compilation/test22538.c(120): Error: variable `test22538.rock2` conflicts with variable `test22538.rock2` at fail_compilation/test22538.c(119)
fail_compilation/test22538.c(123): Error: variable `test22538.stone1` conflicts with variable `test22538.stone1` at fail_compilation/test22538.c(122)
fail_compilation/test22538.c(126): Error: variable `test22538.stone2` conflicts with variable `test22538.stone2` at fail_compilation/test22538.c(125)
---
 */

// https://issues.dlang.org/show_bug.cgi?id=22534

#line 100

// allowed:
static int sun1();
int sun1() { return 0; }

// allowed:
static int sun2() { return 0; }
int sun2();

// fail:
int sun3();
static int sun3() { return 0; }

int sun4() { return 0; }
static int sun4();

static int rock1 = 7;
int rock1;

static int rock2;
int rock2 = 7;

int stone1 = 7;
static int stone1;

int stone2;
static int stone2 = 7;

