// https://issues.dlang.org/show_bug.cgi?id=23789

struct __declspec(align(64)) M128A {
    char c;
};

typedef struct __declspec(align(16)) _M128B {
    int x;
} M128B, *PM128A;


void testpl(p)
struct __declspec(align(2)) S *p;
{
}
