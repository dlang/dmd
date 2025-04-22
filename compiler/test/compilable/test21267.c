// https://github.com/dlang/dmd/issues/21267
static inline __forceinline int square(int x) { return x * x; }

int doSquare(int x) { return square(x); }
