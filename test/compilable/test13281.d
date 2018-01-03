// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:
/*
TEST_OUTPUT:
---
123
123u
123L
123LU
123.5
123.5F
123.5L
123.5i
123.5Fi
123.5Li
(123.5+5.5i)
(123.5F+5.5Fi)
(123.5L+5.5Li)
---
*/
pragma(msg, 123);
pragma(msg, 123u);
pragma(msg, 123L);
pragma(msg, 123uL);
pragma(msg, 123.5);
pragma(msg, 123.5f);
pragma(msg, 123.5L);
pragma(msg, 123.5i);
pragma(msg, 123.5fi);
pragma(msg, 123.5Li);
pragma(msg, 123.5 +5.5i);
pragma(msg, 123.5f+5.5fi);
pragma(msg, 123.5L+5.5Li);

static assert((123  ).stringof == "123");
static assert((123u ).stringof == "123u");
static assert((123L ).stringof == "123L");
static assert((123uL).stringof == "123LU");
static assert((123.5  ).stringof == "123.5");
static assert((123.5f ).stringof == "123.5F");
static assert((123.5L ).stringof == "123.5L");
static assert((123.5i ).stringof == "123.5i");
static assert((123.5fi).stringof == "123.5Fi");
static assert((123.5Li).stringof == "123.5Li");
static assert((123.5 +5.5i ).stringof == "123.5 + 5.5i");
static assert((123.5f+5.5fi).stringof == "123.5F + 5.5Fi");
static assert((123.5L+5.5Li).stringof == "123.5L + 5.5Li");
