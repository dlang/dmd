// https://issues.dlang.org/show_bug.cgi?id=22904

int fn1() { return 0; }
void fn2() { long x = (long) (fn1) (); }
