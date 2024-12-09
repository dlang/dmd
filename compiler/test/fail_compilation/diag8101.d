/*
TEST_OUTPUT:
---
fail_compilation/diag8101.d(114): Error: function `f_0` is not callable using argument types `()`
    f_0();
       ^
fail_compilation/diag8101.d(114):        too few arguments, expected 1, got 0
fail_compilation/diag8101.d(86):        `diag8101.f_0(int)` declared here
void f_0(int);
     ^
fail_compilation/diag8101.d(115): Error: none of the overloads of `f_1` are callable using argument types `()`
    f_1();
       ^
fail_compilation/diag8101.d(88):        Candidates are: `diag8101.f_1(int)`
void f_1(int);
     ^
fail_compilation/diag8101.d(89):                        `diag8101.f_1(int, int)`
void f_1(int, int);
     ^
fail_compilation/diag8101.d(116): Error: none of the overloads of `f_2` are callable using argument types `()`
    f_2();
       ^
fail_compilation/diag8101.d(91):        Candidates are: `diag8101.f_2(int)`
void f_2(int);
     ^
fail_compilation/diag8101.d(92):                        `diag8101.f_2(int, int)`
void f_2(int, int);
     ^
fail_compilation/diag8101.d(93):                        `diag8101.f_2(int, int, int)`
void f_2(int, int, int);
     ^
fail_compilation/diag8101.d(94):                        `diag8101.f_2(int, int, int, int)`
void f_2(int, int, int, int);
     ^
fail_compilation/diag8101.d(95):                        `diag8101.f_2(int, int, int, int, int)`
void f_2(int, int, int, int, int);
     ^
fail_compilation/diag8101.d(96):                        `diag8101.f_2(int, int, int, int, int, int)`
void f_2(int, int, int, int, int, int);
     ^
fail_compilation/diag8101.d(116):        ... (1 more, -v to show) ...
    f_2();
       ^
fail_compilation/diag8101.d(118): Error: template `t_0` is not callable using argument types `!()()`
    t_0();
       ^
fail_compilation/diag8101.d(99):        Candidate is: `t_0(T1)()`
void t_0(T1)();
     ^
fail_compilation/diag8101.d(119): Error: none of the overloads of template `diag8101.t_1` are callable using argument types `!()()`
    t_1();
       ^
fail_compilation/diag8101.d(101):        Candidates are: `t_1(T1)()`
void t_1(T1)();
     ^
fail_compilation/diag8101.d(102):                        `t_1(T1, T2)()`
void t_1(T1, T2)();
     ^
fail_compilation/diag8101.d(120): Error: none of the overloads of template `diag8101.t_2` are callable using argument types `!()()`
    t_2();
       ^
fail_compilation/diag8101.d(104):        Candidates are: `t_2(T1)()`
void t_2(T1)();
     ^
fail_compilation/diag8101.d(105):                        `t_2(T1, T2)()`
void t_2(T1, T2)();
     ^
fail_compilation/diag8101.d(106):                        `t_2(T1, T2, T3)()`
void t_2(T1, T2, T3)();
     ^
fail_compilation/diag8101.d(107):                        `t_2(T1, T2, T3, T4)()`
void t_2(T1, T2, T3, T4)();
     ^
fail_compilation/diag8101.d(108):                        `t_2(T1, T2, T3, T4, T5)()`
void t_2(T1, T2, T3, T4, T5)();
     ^
fail_compilation/diag8101.d(109):                        `t_2(T1, T2, T3, T4, T5, T6)()`
void t_2(T1, T2, T3, T4, T5, T6)();
     ^
fail_compilation/diag8101.d(120):        ... (1 more, -v to show) ...
    t_2();
       ^
---
*/

void f_0(int);

void f_1(int);
void f_1(int, int);

void f_2(int);
void f_2(int, int);
void f_2(int, int, int);
void f_2(int, int, int, int);
void f_2(int, int, int, int, int);
void f_2(int, int, int, int, int, int);
void f_2(int, int, int, int, int, int, int);

void t_0(T1)();

void t_1(T1)();
void t_1(T1, T2)();

void t_2(T1)();
void t_2(T1, T2)();
void t_2(T1, T2, T3)();
void t_2(T1, T2, T3, T4)();
void t_2(T1, T2, T3, T4, T5)();
void t_2(T1, T2, T3, T4, T5, T6)();
void t_2(T1, T2, T3, T4, T5, T6, T7)();

void main()
{
    f_0();
    f_1();
    f_2();

    t_0();
    t_1();
    t_2();
}

// ignored
deprecated void f_2(char);
