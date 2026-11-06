/*
TEST_OUTPUT:
---
fail_compilation/diag8101.d(63): Error: function `f_0` is not callable using argument types `()`
fail_compilation/diag8101.d(63):        too few arguments, expected 1, got 0
fail_compilation/diag8101.d(35):        `diag8101.f_0(int)` declared here
fail_compilation/diag8101.d(64): Error: none of the overloads of `f_1` are callable using argument types `()`
fail_compilation/diag8101.d(37):        Candidates are: `diag8101.f_1(int)`
fail_compilation/diag8101.d(38):                        `diag8101.f_1(int, int)`
fail_compilation/diag8101.d(65): Error: none of the overloads of `f_2` are callable using argument types `()`
fail_compilation/diag8101.d(40):        Candidates are: `diag8101.f_2(int)`
fail_compilation/diag8101.d(41):                        `diag8101.f_2(int, int)`
fail_compilation/diag8101.d(42):                        `diag8101.f_2(int, int, int)`
fail_compilation/diag8101.d(43):                        `diag8101.f_2(int, int, int, int)`
fail_compilation/diag8101.d(44):                        `diag8101.f_2(int, int, int, int, int)`
fail_compilation/diag8101.d(45):                        `diag8101.f_2(int, int, int, int, int, int)`
fail_compilation/diag8101.d(65):        ... (1 more, -v to show) ...
fail_compilation/diag8101.d(67): Error: template `t_0` is not callable using argument types `!()()`
fail_compilation/diag8101.d(67):        missing argument for template parameter #1: `T1`
fail_compilation/diag8101.d(48):        Candidate is: `t_0(T1)()`
fail_compilation/diag8101.d(68): Error: none of the overloads of template `diag8101.t_1` are callable using argument types `!()()`
fail_compilation/diag8101.d(50):        Candidates are: `t_1(T1)()`
fail_compilation/diag8101.d(51):                        `t_1(T1, T2)()`
fail_compilation/diag8101.d(69): Error: none of the overloads of template `diag8101.t_2` are callable using argument types `!()()`
fail_compilation/diag8101.d(53):        Candidates are: `t_2(T1)()`
fail_compilation/diag8101.d(54):                        `t_2(T1, T2)()`
fail_compilation/diag8101.d(55):                        `t_2(T1, T2, T3)()`
fail_compilation/diag8101.d(56):                        `t_2(T1, T2, T3, T4)()`
fail_compilation/diag8101.d(57):                        `t_2(T1, T2, T3, T4, T5)()`
fail_compilation/diag8101.d(58):                        `t_2(T1, T2, T3, T4, T5, T6)()`
fail_compilation/diag8101.d(69):        ... (1 more, -v to show) ...
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
