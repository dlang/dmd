// REQUIRED_ARGS: -main
int f1(bool) { return 1; }
int f1(T)(T) { return 2; }

static assert(f1(    0) == 1);
static assert(f1(    1) == 1);
static assert(f1(   1U) == 1);
static assert(f1(4 - 3) == 1);
