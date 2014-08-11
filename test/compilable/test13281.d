// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:
/*
TEST_OUTPUT:
---
123
123u
123L
123LU
123.4
123.4F
123.4L
123.4i
123.4Fi
123.4Li
(123.4+5.6i)
(123.4F+5.6Fi)
(123.4L+5.6Li)
---
*/
pragma(msg, 123);
pragma(msg, 123u);
pragma(msg, 123L);
pragma(msg, 123uL);
pragma(msg, 123.4);
pragma(msg, 123.4f);
pragma(msg, 123.4L);
pragma(msg, 123.4i);
pragma(msg, 123.4fi);
pragma(msg, 123.4Li);
pragma(msg, 123.4 +5.6i);
pragma(msg, 123.4f+5.6fi);
pragma(msg, 123.4L+5.6Li);

static assert((123  ).stringof == "123");
static assert((123u ).stringof == "123u");
static assert((123L ).stringof == "123L");
static assert((123uL).stringof == "123LU");
static assert((123.4  ).stringof == "123.4");
static assert((123.4f ).stringof == "123.4F");
static assert((123.4L ).stringof == "123.4L");
static assert((123.4i ).stringof == "123.4i");
static assert((123.4fi).stringof == "123.4Fi");
static assert((123.4Li).stringof == "123.4Li");
static assert((123.4 +5.6i ).stringof == "123.4 + 5.6i");
static assert((123.4f+5.6fi).stringof == "123.4F + 5.6Fi");
static assert((123.4L+5.6Li).stringof == "123.4L + 5.6Li");
