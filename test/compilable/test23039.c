/* https://issues.dlang.org/show_bug.cgi?id=23039
 */

const int x = 1;
void fn1() { char x[x]; }
//struct S1 { char x[x]; };

typedef int y;
void fn3() { void(*y)(y); }
//struct S3 { void(*y)(y); };
