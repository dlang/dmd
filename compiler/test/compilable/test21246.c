// https://github.com/dlang/dmd/issues/21246
#define M1(x) _Generic(x, (
#define M2(a,b) _Generic(val, int(int) a
#define M3(str,val) _Generic(val, M(F) struct{int foo;}: 0)(__FILE__, __func__, __LINE__, str, val)
