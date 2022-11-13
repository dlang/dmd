/* RUN_OUTPUT:
---
36
4
---
*/

// https://issues.dlang.org/show_bug.cgi?id=22326

struct S {
    char c;
    int x[0]; // incomplete array type
};

int printf(const char*, ...);

int main(){
    _Alignas(int) char buff[sizeof(struct S) + sizeof(int[8])];
    struct S* s = (struct S*)buff;
    printf("%u\n", (unsigned)sizeof(buff));     // should print 36
    printf("%u\n", (unsigned)sizeof(struct S)); // should print 4
    for(int i = 0; i < 8; i++)
        s->x[i] = i; // program segfaults here
    return 0;
}
