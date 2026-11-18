// REQUIRED_ARGS: -ftime-trace -ftime-trace-granularity=0
// https://github.com/dlang/dmd/issues/24382

enum unused(alias argument) = false;
enum bool value(T) = unused!value;
static assert(!value!int);
