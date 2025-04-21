// https://github.com/dlang/dmd/issues/21273
typedef void (__stdcall *proc)(void);
proc p1;
void (__stdcall *p2)(void);
struct S21273 {
    proc p1;
    void (__stdcall *p2)(void);
};
