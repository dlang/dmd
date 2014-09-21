;; Compiler implementation of the D programming language
;; Copyright (c) 1999-2011 by Digital Mars
;; All Rights Reserved
;; written by Rainer Schuetze
;; http://www.digitalmars.com
;; Distributed under the Boost Software License, Version 1.0.
;; http://www.boost.org/LICENSE_1_0.txt
;; https://github.com/D-Programming-Language/dmd/blob/master/src/test/UTFTest.cpp

;; 80 bit floating point value implementation for Microsoft compiler

;.386
;.model flat, c

; Custom Build Step, including a listing file placed in intermediate directory
; debug:
; ml -c -Zi "-Fl$(IntDir)\$(InputName).lst" "-Fo$(IntDir)\$(InputName).obj" "$(InputPath)"
; release:
; ml -c "-Fl$(IntDir)\$(InputName).lst" "-Fo$(IntDir)\$(InputName).obj" "$(InputPath)"
; outputs:
; $(IntDir)\$(InputName).obj

.data

twoPow63 dd 0, 80000000h, 03fffh + 63

.code

; double ld_read(longdouble* ld);
; rcx: ld
ld_read PROC
	fld tbyte ptr [rcx]
	push rax
	fstp qword ptr [rsp]
	movq xmm0,qword ptr [rsp]
	pop rax
	ret
ld_read ENDP

; long long ld_readll(longdouble* ld);
; rcx: ld
;ld_readll PROC
;	fld tbyte ptr [rcx]
;	push rax
;	fistp qword ptr [rsp]
;	pop rax
;	ret
;ld_readll ENDP

; unsigned long long ld_readull(longdouble* ld);
; rcx: ld
;ld_readull PROC
;	fld tbyte ptr [rcx]
;	push rax
;	lea rax,twoPow63
;	fld tbyte ptr [rax]
;	fsubp ST(1),ST(0)  ; move it into signed range
;	fistp qword ptr [rsp]
;	pop rax
;	btc rax,63
;	ret
;ld_readull ENDP

; void ld_set(longdouble* ld, double d);
; rcx: ld
; xmm1: d
ld_set PROC
	push rax
	movq qword ptr [rsp],xmm1
	fld qword ptr [rsp]
	fstp tbyte ptr [rcx]
	pop rax
	ret
ld_set ENDP

; void ld_setll(longdouble* ld, long long d);
; rcx: ld
; rdx: d
ld_setll PROC
	push rdx
	fild qword ptr [rsp]
    fstp tbyte ptr [rcx]
    pop rax
	ret
ld_setll ENDP

; void ld_setull(longdouble* ld, long long d);
; rcx: ld
; rax: d
ld_setull PROC
	btc rdx,63
	push rdx
	fild qword ptr [rsp]
	lea rax,twoPow63
	fld tbyte ptr [rax]
	faddp ST(1),ST(0)
    fstp tbyte ptr [rcx]
    pop rax
	ret
ld_setull ENDP

; void ld_expl(longdouble* ld, int exp);
; rcx: ld
; edx: exp
ld_expl PROC
	push rdx
	fild    dword ptr [rsp]
	fld     tbyte ptr [rcx]
	fscale                  ; ST(0) = ST(0) * (2**ST(1))
	fstp    ST(1)
	fstp    tbyte ptr [rcx]
    pop rax
	ret
ld_expl ENDP

; long_double ld_add(long_double ld1, long_double ld2);
; rcx: &res
; rdx: &ld1
; r8:  &ld2
ld_add PROC
	fld tbyte ptr [r8]
	fld tbyte ptr [rdx]
	fadd
	fstp tbyte ptr [rcx]
	mov rax,rcx
	ret
ld_add ENDP

; long_double ld_sub(long_double ld1, long_double ld2);
; rcx: &res
; rdx: &ld1
; r8:  &ld2
ld_sub PROC
	fld tbyte ptr [rdx]
	fld tbyte ptr [r8]
	fsub
	fstp tbyte ptr [rcx]
	mov rax,rcx
	ret
ld_sub ENDP

; long_double ld_mul(long_double ld1, long_double ld2);
; rcx: &res
; rdx: &ld1
; r8:  &ld2
ld_mul PROC
	fld tbyte ptr [r8]
	fld tbyte ptr [rdx]
	fmul
	fstp tbyte ptr [rcx]
	mov rax,rcx
	ret
ld_mul ENDP

; long_double ld_div(long_double ld1, long_double ld2);
; rcx: &res
; rdx: &ld1
; r8:  &ld2
ld_div PROC
	fld tbyte ptr [rdx]
	fld tbyte ptr [r8]
	fdiv
	fstp tbyte ptr [rcx]
	mov rax,rcx
	ret
ld_div ENDP

; long_double ld_mod(long_double ld1, long_double ld2);
; rcx: &res
; rdx: &ld1
; r8:  &ld2
ld_mod PROC
	push rax
        fld     tbyte ptr [r8]
        fld     tbyte ptr [rdx]         ; ST = x, ST1 = y
FM1:    ; We don't use fprem1 because for some inexplicable
        ; reason we get -5 when we do _modulo(15, 10)
        fprem                           ; ST = ST % ST1
        fstsw   word ptr [rsp]
        fwait
        mov     AH,byte ptr [rsp+1]     ; get msb of status word in AH
        sahf                            ; transfer to flags
        jp      FM1                     ; continue till ST < ST1
        fstp    ST(1)                   ; leave remainder on stack
        fstp    tbyte ptr [ecx]
	pop rax
	mov rax,rcx
	ret
ld_mod ENDP

; bool ld_cmpb(long_double x, long_double y);
; rcx: &x
; rdx: &y
ld_cmpb PROC
	fld tbyte ptr [rdx]
	fld tbyte ptr [rcx]
	fucomip ST(0),ST(1)
	setb    AL
	setnp   AH
	and     AL,AH
	fstp    ST(0)
	ret
ld_cmpb ENDP

; bool ld_cmpbe(long_double x, long_double y);
; rcx: &x
; rdx: &y
ld_cmpbe PROC
	fld tbyte ptr [rdx]
	fld tbyte ptr [rcx]
	fucomip ST(0),ST(1)
	setbe   AL
	setnp   AH
	and     AL,AH
	fstp    ST(0)
	ret
ld_cmpbe ENDP

; bool ld_cmpa(long_double x, long_double y);
; rcx: &x
; rdx: &y
ld_cmpa PROC
	fld tbyte ptr [rdx]
	fld tbyte ptr [rcx]
	fucomip ST(0),ST(1)
	seta    AL
	setnp   AH
	and     AL,AH
	fstp    ST(0)
	ret
ld_cmpa ENDP

; bool ld_cmpae(long_double x, long_double y);
; rcx: &x
; rdx: &y
ld_cmpae PROC
	fld tbyte ptr [rdx]
	fld tbyte ptr [rcx]
	fucomip ST(0),ST(1)
	setae   AL
	setnp   AH
	and     AL,AH
	fstp    ST(0)
	ret
ld_cmpae ENDP

; bool ld_cmpe(long_double x, long_double y);
; rcx: &x
; rdx: &y
ld_cmpe PROC
	fld tbyte ptr [rdx]
	fld tbyte ptr [rcx]
	fucomip ST(0),ST(1)
	sete    AL
	setnp   AH
	and     AL,AH
	fstp    ST(0)
	ret
ld_cmpe ENDP

; bool ld_cmpne(long_double x, long_double y);
; rcx: &x
; rdx: &y
ld_cmpne PROC
	fld tbyte ptr [rdx]
	fld tbyte ptr [rcx]
	fucomip ST(0),ST(1)
	setne   AL
	setp    AH
	or      AL,AH
	fstp    ST(0)
	ret
ld_cmpne ENDP

; long_double ld_sqrt(long_double x);
; rcx: &res
; rdx: &x
ld_sqrt PROC
	fld tbyte ptr [rdx]
	fsqrt
	fstp tbyte ptr [rcx]
	mov rax,rcx
	ret
ld_sqrt ENDP

; long_double ld_sin(long_double x);
; rcx: &res
; rdx: &x
ld_sin PROC
	fld tbyte ptr [rdx]
	fsin
	fstp tbyte ptr [rcx]
	mov rax,rcx
	ret
ld_sin ENDP

; long_double ld_cos(long_double x);
; rcx: &res
; rdx: &x
ld_cos PROC
	fld tbyte ptr [rdx]
	fcos
	fstp tbyte ptr [rcx]
	mov rax,rcx
	ret
ld_cos ENDP

; long_double ld_tan(long_double x);
; rcx: &res
; rdx: &x
ld_tan PROC
	fld tbyte ptr [rdx]
	fptan
	fstp st(0)
	fstp tbyte ptr [rcx]
	mov rax,rcx
	ret
ld_tan ENDP

; int ld_initfpu(int bits, int mask)
; ecx: bits
; edx: mask
ld_initfpu PROC
	push    rcx
	fstcw   word ptr [rsp]
	movzx   EAX,word ptr [rsp] ; also return old CW in EAX
	not     EDX
	and     EDX,EAX
	or      ECX,EDX
	mov     dword ptr [rsp],ECX
	fldcw   word ptr [rsp]
	pop     rcx
	ret
ld_initfpu ENDP

end
