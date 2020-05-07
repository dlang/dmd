// REQUIRED_ARGS:

import std.math: poly;

extern(C)
{
    int printf(const char*, ...);
}

/*************************************/

real poly_asm(real x, real[] A)
in
{
    assert(A.length > 0);
}
do
{
    version (D_InlineAsm_X86)
    {
        version (linux)
        {
        asm     // assembler by W. Bright
        {
            // EDX = (A.length - 1) * real.sizeof
            mov     ECX,A[EBP]          ; // ECX = A.length
            dec     ECX                 ;
            lea     EDX,[ECX][ECX*8]    ;
            add     EDX,ECX             ;
            add     EDX,ECX             ;
            add     EDX,ECX             ;
            add     EDX,A+4[EBP]        ;
            fld     real ptr [EDX]      ; // ST0 = coeff[ECX]
            jecxz   return_ST           ;
            fld     x[EBP]              ; // ST0 = x
            fxch    ST(1)               ; // ST1 = x, ST0 = r
            align   4                   ;
    L2:     fmul    ST,ST(1)            ; // r *= x
            fld     real ptr -12[EDX]   ;
            sub     EDX,12              ; // deg--
            faddp   ST(1),ST            ;
            dec     ECX                 ;
            jne     L2                  ;
            fxch    ST(1)               ; // ST1 = r, ST0 = x
            fstp    ST(0)               ; // dump x
            align   4                   ;
    return_ST:                          ;
            ;
        }
        }
        else version (OSX)
        {
            asm // assembler by W. Bright
            {
                // EDX = (A.length - 1) * real.sizeof
                mov     ECX,A[EBP]              ; // ECX = A.length
                dec     ECX                     ;
                lea     EDX,[ECX*8]             ;
                add     EDX,EDX                 ;
                add     EDX,A+4[EBP]            ;
                fld     real ptr [EDX]          ; // ST0 = coeff[ECX]
                jecxz   return_ST               ;
                fld     x[EBP]                  ; // ST0 = x
                fxch    ST(1)                   ; // ST1 = x, ST0 = r
                align   4                       ;
        L2:     fmul    ST,ST(1)                ; // r *= x
                fld     real ptr -16[EDX]       ;
                sub     EDX,16                  ; // deg--
                faddp   ST(1),ST                ;
                dec     ECX                     ;
                jne     L2                      ;
                fxch    ST(1)                   ; // ST1 = r, ST0 = x
                fstp    ST(0)                   ; // dump x
                align   4                       ;
        return_ST:                              ;
                ;
            }
        }
        else version (FreeBSD)
        {
        asm     // assembler by W. Bright
        {
            // EDX = (A.length - 1) * real.sizeof
            mov     ECX,A[EBP]          ; // ECX = A.length
            dec     ECX                 ;
            lea     EDX,[ECX][ECX*8]    ;
            add     EDX,ECX             ;
            add     EDX,ECX             ;
            add     EDX,ECX             ;
            add     EDX,A+4[EBP]        ;
            fld     real ptr [EDX]      ; // ST0 = coeff[ECX]
            jecxz   return_ST           ;
            fld     x[EBP]              ; // ST0 = x
            fxch    ST(1)               ; // ST1 = x, ST0 = r
            align   4                   ;
    L2:     fmul    ST,ST(1)            ; // r *= x
            fld     real ptr -12[EDX]   ;
            sub     EDX,12              ; // deg--
            faddp   ST(1),ST            ;
            dec     ECX                 ;
            jne     L2                  ;
            fxch    ST(1)               ; // ST1 = r, ST0 = x
            fstp    ST(0)               ; // dump x
            align   4                   ;
    return_ST:                          ;
            ;
        }
        }
        else version (Solaris)
        {
        asm     // assembler by W. Bright
        {
            // EDX = (A.length - 1) * real.sizeof
            mov     ECX,A[EBP]          ; // ECX = A.length
            dec     ECX                 ;
            lea     EDX,[ECX][ECX*8]    ;
            add     EDX,ECX             ;
            add     EDX,ECX             ;
            add     EDX,ECX             ;
            add     EDX,A+4[EBP]        ;
            fld     real ptr [EDX]      ; // ST0 = coeff[ECX]
            jecxz   return_ST           ;
            fld     x[EBP]              ; // ST0 = x
            fxch    ST(1)               ; // ST1 = x, ST0 = r
            align   4                   ;
    L2:     fmul    ST,ST(1)            ; // r *= x
            fld     real ptr -12[EDX]   ;
            sub     EDX,12              ; // deg--
            faddp   ST(1),ST            ;
            dec     ECX                 ;
            jne     L2                  ;
            fxch    ST(1)               ; // ST1 = r, ST0 = x
            fstp    ST(0)               ; // dump x
            align   4                   ;
    return_ST:                          ;
            ;
        }
        }
        else
        {
        asm     // assembler by W. Bright
        {
            // EDX = (A.length - 1) * real.sizeof
            mov     ECX,A[EBP]          ; // ECX = A.length
            dec     ECX                 ;
            lea     EDX,[ECX][ECX*8]    ;
            add     EDX,ECX             ;
            add     EDX,A+4[EBP]        ;
            fld     real ptr [EDX]      ; // ST0 = coeff[ECX]
            jecxz   return_ST           ;
            fld     x[EBP]              ; // ST0 = x
            fxch    ST(1)               ; // ST1 = x, ST0 = r
            align   4                   ;
    L2:     fmul    ST,ST(1)            ; // r *= x
            fld     real ptr -10[EDX]   ;
            sub     EDX,10              ; // deg--
            faddp   ST(1),ST            ;
            dec     ECX                 ;
            jne     L2                  ;
            fxch    ST(1)               ; // ST1 = r, ST0 = x
            fstp    ST(0)               ; // dump x
            align   4                   ;
    return_ST:                          ;
            ;
        }
        }
    }
    else
    {
        printf("Sorry, you don't seem to have InlineAsm_X86\n");
        return 0;
    }
}

real poly_c(real x, real[] A)
in
{
    assert(A.length > 0);
}
do
{
    ptrdiff_t i = A.length - 1;
    real r = A[i];
    while (--i >= 0)
    {
        r *= x;
        r += A[i];
    }
    return r;
}

void test47()
{
    real x = 3.1;
    static real[] pp = [56.1, 32.7, 6];
    real r;

    printf("The result should be %Lf\n",(56.1L + (32.7L + 6L * x) * x));
    printf("The C version outputs %Lf\n", poly_c(x, pp));
    printf("The asm version outputs %Lf\n", poly_asm(x, pp));
    printf("The std.math version outputs %Lf\n", poly(x, pp));

    r = (56.1L + (32.7L + 6L * x) * x);
    assert(r == poly_c(x, pp));
    version (D_InlineAsm_X86)
        assert(r == poly_asm(x, pp));
    assert(r == poly(x, pp));
}

/*************************************/

import std.stdio;
import core.stdc.stdarg;

void myfunc(int a1, ...) {
        va_list argument_list;
        TypeInfo argument_type;
        string sa; int ia; double da;
        writefln("%d variable arguments", _arguments.length);
        writefln("argument types %s", _arguments);
        va_start(argument_list, a1);
        for (int i = 0; i < _arguments.length; ) {
                if ((argument_type=_arguments[i++]) == typeid(string)) {
                        va_arg(argument_list, sa);
                        writefln("%d) string arg = '%s', length %d", i+1, sa.length<=20? sa : "?", sa.length);
                } else if (argument_type == typeid(int)) {
                        va_arg(argument_list, ia);
                        writefln("%d) int arg = %d", i+1, ia);
                } else if (argument_type == typeid(double)) {
                        va_arg(argument_list, da);
                        writefln("%d) double arg = %f", i+1, da);
                } else {
                        throw new Exception("invalid argument type");
                }
        }
        va_end(argument_list);
}

void test6758() {
        myfunc(1, 2, 3, 4, 5, 6, 7, 8, "9", "10");                              // Fails.
        myfunc(1, 2.0, 3, 4, 5, 6, 7, 8, "9", "10");                    // Works OK.
        myfunc(1, 2, 3, 4, 5, 6, 7, "8", "9", "10");                    // Works OK.
        myfunc(1, "2", 3, 4, 5, 6, 7, 8, "9", "10");                    // Works OK.
}

/*************************************/

int main()
{
    test47();
    test6758();

    printf("Success\n");
    return 0;
}
