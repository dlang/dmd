alias void FuncType();

struct Opaque;

template Tuple(T...) { alias T Tuple; }
alias Tuple!(int, int) TupleType;

/******************************************/
// return type

/*
TEST_OUTPUT:
---
fail_compilation/fail12436.d(46): Error: functions cannot return a function
FuncType test1();
         ^
fail_compilation/fail12436.d(47): Error: functions cannot return a sequence (use `std.typecons.Tuple`)
TupleType test2();
          ^
fail_compilation/fail12436.d(49): Error: functions cannot return opaque type `Opaque` by value
Opaque    ret12436a();  // error
          ^
fail_compilation/fail12436.d(50): Error: functions cannot return opaque type `Opaque[1]` by value
Opaque[1] ret12436b();  // error
          ^
fail_compilation/fail12436.d(61): Error: cannot have parameter of function type `void()`
void test3(FuncType) {}
     ^
fail_compilation/fail12436.d(63): Error: cannot have parameter of opaque type `Opaque` by value
void param12436a(Opaque);     // error
     ^
fail_compilation/fail12436.d(64): Error: cannot have parameter of opaque type `Opaque[1]` by value
void param12436b(Opaque[1]);  // error
     ^
fail_compilation/fail12436.d(75): Error: cannot have parameter of opaque type `A14906` by value
void f14906a(A14906) {}
     ^
fail_compilation/fail12436.d(76): Error: cannot have parameter of opaque type `A14906[3]` by value
void f14906b(A14906[3]) {}
     ^
fail_compilation/fail12436.d(77): Error: cannot have parameter of opaque type `A14906[3][3]` by value
void f14906c(A14906[3][3]) {}
     ^
---
*/
FuncType test1();
TupleType test2();

Opaque    ret12436a();  // error
Opaque[1] ret12436b();  // error
Opaque*   ret12436c();  // no error
Opaque[]  ret12436d();  // no error
Opaque[]* ret12436e();  // no error

ref Opaque    ret12436f();  // no error
ref Opaque[1] ret12436g();  // no error

/******************************************/
// parameter type

void test3(FuncType) {}

void param12436a(Opaque);     // error
void param12436b(Opaque[1]);  // error
void param12436c(Opaque*);    // no error
void param12436d(Opaque[]);   // no error
void param12436e(Opaque[]*);  // no error

void param12436f(ref Opaque);     // no error
void param12436g(ref Opaque[1]);  // no error
void param12436h(out Opaque);     // no error
void param12436i(out Opaque[1]);  // no error

enum A14906;
void f14906a(A14906) {}
void f14906b(A14906[3]) {}
void f14906c(A14906[3][3]) {}
