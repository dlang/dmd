// https://issues.dlang.org/show_bug.cgi?id=22904

int fn1() { return 0; }
void fn2() { long x = (long) (fn1) (); }

// https://issues.dlang.org/show_bug.cgi?id=22912

typedef long my_long;
void fn3() { long x = (my_long) (fn1) (); }

// https://issues.dlang.org/show_bug.cgi?id=22913

void fn4()
{
    int a[1];
    int b = (a[0]);
}
