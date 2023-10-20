// https://issues.dlang.org/show_bug.cgi?id=22886

struct config *Configlist_add(int);
struct config *Configlist_add(int) { return 0; }

struct config { int dot; };
