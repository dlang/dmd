// https://issues.dlang.org/show_bug.cgi?id=22705


Ta *pa;
struct Sa { int x; };
typedef struct Sa Ta;

Tb *pb;
struct Sb;
typedef struct Sb { int x; } Tb;

struct S1;
struct S2 { int x; };
typedef struct S2 T;
struct S1 { T* pc; };
