// https://issues.dlang.org/show_bug.cgi?id=22757

typedef struct S S;

struct T {
    int x;
};
struct S {
    struct T *pChunk;
};
void foo(struct S pS){
    void *p = &pS.pChunk;
}
