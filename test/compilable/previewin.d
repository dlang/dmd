/* REQUIRED_ARGS: -preview=dip1000 -preview=in
 */

@safe:
void fun(in int* inParam);
static assert([__traits(getParameterStorageClasses, fun, 0)] == ["in"]);
static assert (is(typeof(fun) P == __parameters) && is(P[0] == const int*));
