extern(C) void c_ok1(ref int[4] x);
extern(C) void c_ok2(out int[4] x);
extern(C) void c_ok3(int[4]* x);
extern(C) ref int[4] c_ok4();
extern(C) int[4]* c_ok5();
extern(C++) void c_ok7(ref int[4] x);
extern(C++) void c_ok8(out int[4] x);
extern(C++) void c_ok9(int[4]* x);
extern(C++) ref int[4] c_ok10();
extern(C++) int[4]* c_ok11();

void main() { }
