// https://issues.dlang.org/show_bug.cgi?id=10560

// After the deprecation period for DIP 1015 has expired,
// uncomment everything below.

// int f(bool b) { return 1; }
// int f(int i) { return 2; }

// enum E : int
// {
//     a = 0,
//     b = 1,
//     c = 2,
// }

void main()
{
    // assert(f(E.a) == 2);
    // assert(f(E.b) == 2);
    // assert(f(E.c) == 2);
}
