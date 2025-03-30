// https://issues.dlang.org/show_bug.cgi?id=24505

// PERMUTE_ARGS:

struct stat { int x; };

void __stat(int x, int y);
#define stat(x, y) __stat(x, y)

// reversed order:
#define stat2(x, y) __stat(x, y)
struct stat2 { int x; };

#undef stat
#undef stat2
