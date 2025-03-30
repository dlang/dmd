// https://issues.dlang.org/show_bug.cgi?id=22929

extern int xs[];
void fn() { void *xp = &(xs[0]); }

struct S { char text[4]; };
extern struct S ops[];
char *args[] = { ops[1].text };
