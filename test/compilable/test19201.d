// https://issues.dlang.org/show_bug.cgi?id=19201
enum __c_long : int;
enum __c_ulong : uint;

enum __c_longlong : long;
enum __c_ulonglong : ulong;

void test19201a(uint r);
void test19201a(int r);

void test19201b(ulong r);
void test19201b(long r);

void test19201c(__c_long r);
void test19201c(__c_ulong r);

void test19201d(__c_longlong r);
void test19201d(__c_ulonglong r);

void test19201()
{
    test19201a(0);
    test19201a(0u);
    test19201b(0L);
    test19201b(0UL);
    test19201c(0);
    test19201c(0u);
    test19201d(0L);
    test19201d(0UL);
}
