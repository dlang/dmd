// https://issues.dlang.org/show_bug.cgi?id=22623

struct S {
    struct T *child;
};

typedef
struct T {
    int xyz;
} U;

void fn()
{
    struct S s;
    struct T t;
    if (s.child != &t)
	;
}
