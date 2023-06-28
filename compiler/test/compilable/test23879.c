// https://issues.dlang.org/show_bug.cgi?id=23879

struct S { int x; };

int x = __alignof(struct S);
int y = _Alignof(struct S);
